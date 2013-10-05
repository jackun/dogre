


typedef char *String;
typedef struct _WidgetRec *Widget;
typedef Widget *WidgetList;
typedef struct _WidgetClassRec *WidgetClass;
typedef struct _CompositeRec *CompositeWidget;
typedef struct _XtActionsRec *XtActionList;
typedef struct _XtEventRec *XtEventTable;

typedef struct _XtAppStruct *XtAppContext;
typedef unsigned long XtValueMask;
typedef unsigned long XtIntervalId;
typedef unsigned long XtInputId;
typedef unsigned long XtWorkProcId;
typedef unsigned long XtSignalId;
typedef unsigned int XtGeometryMask;
typedef unsigned long XtGCMask;
typedef unsigned long Pixel;
typedef int XtCacheType;
typedef char Boolean;
typedef long XtArgVal;
typedef unsigned char XtEnum;


typedef unsigned int Cardinal;
typedef unsigned short Dimension;
typedef short Position;

typedef void* XtPointer;


typedef struct _CompositeClassRec *CompositeWidgetClass;
typedef Cardinal (*XtOrderProc)(
    Widget
);


extern void XtManageChildren(
    WidgetList ,
    Cardinal
);

extern void XtManageChild(
    Widget
);

extern void XtUnmanageChildren(
    WidgetList ,
    Cardinal
);

extern void XtUnmanageChild(
    Widget
);

typedef void (*XtDoChangeProc)(
    Widget ,
    WidgetList ,
    Cardinal * ,
    WidgetList ,
    Cardinal * ,
    XtPointer
);

extern void XtChangeManagedSet(
    WidgetList ,
    Cardinal ,
    XtDoChangeProc ,
    XtPointer ,
    WidgetList ,
    Cardinal
);






















typedef unsigned char __u_char;
typedef unsigned short int __u_short;
typedef unsigned int __u_int;
typedef unsigned long int __u_long;


typedef signed char __int8_t;
typedef unsigned char __uint8_t;
typedef signed short int __int16_t;
typedef unsigned short int __uint16_t;
typedef signed int __int32_t;
typedef unsigned int __uint32_t;

typedef signed long int __int64_t;
typedef unsigned long int __uint64_t;







typedef long int __quad_t;
typedef unsigned long int __u_quad_t;


typedef unsigned long int __dev_t;
typedef unsigned int __uid_t;
typedef unsigned int __gid_t;
typedef unsigned long int __ino_t;
typedef unsigned long int __ino64_t;
typedef unsigned int __mode_t;
typedef unsigned long int __nlink_t;
typedef long int __off_t;
typedef long int __off64_t;
typedef int __pid_t;
typedef struct { int __val[2]; } __fsid_t;
typedef long int __clock_t;
typedef unsigned long int __rlim_t;
typedef unsigned long int __rlim64_t;
typedef unsigned int __id_t;
typedef long int __time_t;
typedef unsigned int __useconds_t;
typedef long int __suseconds_t;

typedef int __daddr_t;
typedef int __key_t;


typedef int __clockid_t;


typedef void * __timer_t;


typedef long int __blksize_t;




typedef long int __blkcnt_t;
typedef long int __blkcnt64_t;


typedef unsigned long int __fsblkcnt_t;
typedef unsigned long int __fsblkcnt64_t;


typedef unsigned long int __fsfilcnt_t;
typedef unsigned long int __fsfilcnt64_t;


typedef long int __fsword_t;

typedef long int __ssize_t;


typedef long int __syscall_slong_t;

typedef unsigned long int __syscall_ulong_t;



typedef __off64_t __loff_t;
typedef __quad_t *__qaddr_t;
typedef char *__caddr_t;


typedef long int __intptr_t;


typedef unsigned int __socklen_t;



typedef __u_char u_char;
typedef __u_short u_short;
typedef __u_int u_int;
typedef __u_long u_long;
typedef __quad_t quad_t;
typedef __u_quad_t u_quad_t;
typedef __fsid_t fsid_t;




typedef __loff_t loff_t;



typedef __ino_t ino_t;
typedef __dev_t dev_t;




typedef __gid_t gid_t;




typedef __mode_t mode_t;




typedef __nlink_t nlink_t;




typedef __uid_t uid_t;





typedef __off_t off_t;
typedef __pid_t pid_t;





typedef __id_t id_t;




typedef __ssize_t ssize_t;





typedef __daddr_t daddr_t;
typedef __caddr_t caddr_t;





typedef __key_t key_t;


typedef __clock_t clock_t;





typedef __time_t time_t;



typedef __clockid_t clockid_t;
typedef __timer_t timer_t;
typedef long unsigned int size_t;



typedef unsigned long int ulong;
typedef unsigned short int ushort;
typedef unsigned int uint;
typedef int int8_t __attribute__ ((__mode__ (__QI__)));
typedef int int16_t __attribute__ ((__mode__ (__HI__)));
typedef int int32_t __attribute__ ((__mode__ (__SI__)));
typedef int int64_t __attribute__ ((__mode__ (__DI__)));


typedef unsigned int u_int8_t __attribute__ ((__mode__ (__QI__)));
typedef unsigned int u_int16_t __attribute__ ((__mode__ (__HI__)));
typedef unsigned int u_int32_t __attribute__ ((__mode__ (__SI__)));
typedef unsigned int u_int64_t __attribute__ ((__mode__ (__DI__)));

typedef int register_t __attribute__ ((__mode__ (__word__)));






static __inline unsigned int
__bswap_32 (unsigned int __bsx)
{
  return __builtin_bswap32 (__bsx);
}
static __inline __uint64_t
__bswap_64 (__uint64_t __bsx)
{
  return __builtin_bswap64 (__bsx);
}




typedef int __sig_atomic_t;




typedef struct
  {
    unsigned long int __val[(1024 / (8 * sizeof (unsigned long int)))];
  } __sigset_t;



typedef __sigset_t sigset_t;





struct timespec
  {
    __time_t tv_sec;
    __syscall_slong_t tv_nsec;
  };

struct timeval
  {
    __time_t tv_sec;
    __suseconds_t tv_usec;
  };


typedef __suseconds_t suseconds_t;





typedef long int __fd_mask;
typedef struct
  {






    __fd_mask __fds_bits[1024 / (8 * (int) sizeof (__fd_mask))];


  } fd_set;






typedef __fd_mask fd_mask;

extern int select (int __nfds, fd_set *__restrict __readfds,
     fd_set *__restrict __writefds,
     fd_set *__restrict __exceptfds,
     struct timeval *__restrict __timeout);
extern int pselect (int __nfds, fd_set *__restrict __readfds,
      fd_set *__restrict __writefds,
      fd_set *__restrict __exceptfds,
      const struct timespec *__restrict __timeout,
      const __sigset_t *__restrict __sigmask);





__extension__
extern unsigned int gnu_dev_major (unsigned long long int __dev)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
__extension__
extern unsigned int gnu_dev_minor (unsigned long long int __dev)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
__extension__
extern unsigned long long int gnu_dev_makedev (unsigned int __major,
            unsigned int __minor)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));






typedef __blksize_t blksize_t;






typedef __blkcnt_t blkcnt_t;



typedef __fsblkcnt_t fsblkcnt_t;



typedef __fsfilcnt_t fsfilcnt_t;
typedef unsigned long int pthread_t;


union pthread_attr_t
{
  char __size[56];
  long int __align;
};

typedef union pthread_attr_t pthread_attr_t;





typedef struct __pthread_internal_list
{
  struct __pthread_internal_list *__prev;
  struct __pthread_internal_list *__next;
} __pthread_list_t;
typedef union
{
  struct __pthread_mutex_s
  {
    int __lock;
    unsigned int __count;
    int __owner;

    unsigned int __nusers;



    int __kind;

    int __spins;
    __pthread_list_t __list;
  } __data;
  char __size[40];
  long int __align;
} pthread_mutex_t;

typedef union
{
  char __size[4];
  int __align;
} pthread_mutexattr_t;




typedef union
{
  struct
  {
    int __lock;
    unsigned int __futex;
    __extension__ unsigned long long int __total_seq;
    __extension__ unsigned long long int __wakeup_seq;
    __extension__ unsigned long long int __woken_seq;
    void *__mutex;
    unsigned int __nwaiters;
    unsigned int __broadcast_seq;
  } __data;
  char __size[48];
  __extension__ long long int __align;
} pthread_cond_t;

typedef union
{
  char __size[4];
  int __align;
} pthread_condattr_t;



typedef unsigned int pthread_key_t;



typedef int pthread_once_t;





typedef union
{

  struct
  {
    int __lock;
    unsigned int __nr_readers;
    unsigned int __readers_wakeup;
    unsigned int __writer_wakeup;
    unsigned int __nr_readers_queued;
    unsigned int __nr_writers_queued;
    int __writer;
    int __shared;
    unsigned long int __pad1;
    unsigned long int __pad2;


    unsigned int __flags;

  } __data;
  char __size[56];
  long int __align;
} pthread_rwlock_t;

typedef union
{
  char __size[8];
  long int __align;
} pthread_rwlockattr_t;





typedef volatile int pthread_spinlock_t;




typedef union
{
  char __size[32];
  long int __align;
} pthread_barrier_t;

typedef union
{
  char __size[4];
  int __align;
} pthread_barrierattr_t;








typedef unsigned long XID;



typedef unsigned long Mask;



typedef unsigned long Atom;

typedef unsigned long VisualID;
typedef unsigned long Time;
typedef XID Window;
typedef XID Drawable;


typedef XID Font;

typedef XID Pixmap;
typedef XID Cursor;
typedef XID Colormap;
typedef XID GContext;
typedef XID KeySym;
    
typedef unsigned char KeyCode;
typedef long int ptrdiff_t;

extern int
_Xmblen(
    char *str,
    int len

    );





typedef char *XPointer;
typedef struct _XExtData {
 int number;
 struct _XExtData *next;
 int (*free_private)(
 struct _XExtData *extension
 );
 XPointer private_data;
} XExtData;




typedef struct {
 int extension;
 int major_opcode;
 int first_event;
 int first_error;
} XExtCodes;





typedef struct {
    int depth;
    int bits_per_pixel;
    int scanline_pad;
} XPixmapFormatValues;





typedef struct {
 int function;
 unsigned long plane_mask;
 unsigned long foreground;
 unsigned long background;
 int line_width;
 int line_style;
 int cap_style;

 int join_style;
 int fill_style;

 int fill_rule;
 int arc_mode;
 Pixmap tile;
 Pixmap stipple;
 int ts_x_origin;
 int ts_y_origin;
        Font font;
 int subwindow_mode;
 int graphics_exposures;
 int clip_x_origin;
 int clip_y_origin;
 Pixmap clip_mask;
 int dash_offset;
 char dashes;
} XGCValues;

typedef struct _XGC *GC;


typedef struct {
 XExtData *ext_data;
 VisualID visualid;
 int _class;

 unsigned long red_mask, green_mask, blue_mask;
 int bits_per_rgb;
 int map_entries;
} Visual;




typedef struct {
 int depth;
 int nvisuals;
 Visual *visuals;
} Depth;







struct _XDisplay;

typedef struct {
 XExtData *ext_data;
 struct _XDisplay *display;
 Window root;
 int width, height;
 int mwidth, mheight;
 int ndepths;
 Depth *depths;
 int root_depth;
 Visual *root_visual;
 GC default_gc;
 Colormap cmap;
 unsigned long white_pixel;
 unsigned long black_pixel;
 int max_maps, min_maps;
 int backing_store;
 int save_unders;
 long root_input_mask;
} Screen;




typedef struct {
 XExtData *ext_data;
 int depth;
 int bits_per_pixel;
 int scanline_pad;
} ScreenFormat;




typedef struct {
    Pixmap background_pixmap;
    unsigned long background_pixel;
    Pixmap border_pixmap;
    unsigned long border_pixel;
    int bit_gravity;
    int win_gravity;
    int backing_store;
    unsigned long backing_planes;
    unsigned long backing_pixel;
    int save_under;
    long event_mask;
    long do_not_propagate_mask;
    int override_redirect;
    Colormap colormap;
    Cursor cursor;
} XSetWindowAttributes;

typedef struct {
    int x, y;
    int width, height;
    int border_width;
    int depth;
    Visual *visual;
    Window root;



    int _class;

    int bit_gravity;
    int win_gravity;
    int backing_store;
    unsigned long backing_planes;
    unsigned long backing_pixel;
    int save_under;
    Colormap colormap;
    int map_installed;
    int map_state;
    long all_event_masks;
    long your_event_mask;
    long do_not_propagate_mask;
    int override_redirect;
    Screen *screen;
} XWindowAttributes;






typedef struct {
 int family;
 int length;
 char *address;
} XHostAddress;




typedef struct {
 int typelength;
 int valuelength;
 char *type;
 char *value;
} XServerInterpretedAddress;




typedef struct _XImage {
    int width, height;
    int xoffset;
    int format;
    char *data;
    int byte_order;
    int bitmap_unit;
    int bitmap_bit_order;
    int bitmap_pad;
    int depth;
    int bytes_per_line;
    int bits_per_pixel;
    unsigned long red_mask;
    unsigned long green_mask;
    unsigned long blue_mask;
    XPointer obdata;
    struct funcs {
 struct _XImage *(*create_image)(
  struct _XDisplay* ,
  Visual* ,
  unsigned int ,
  int ,
  int ,
  char* ,
  unsigned int ,
  unsigned int ,
  int ,
  int );
 int (*destroy_image) (struct _XImage *);
 unsigned long (*get_pixel) (struct _XImage *, int, int);
 int (*put_pixel) (struct _XImage *, int, int, unsigned long);
 struct _XImage *(*sub_image)(struct _XImage *, int, int, unsigned int, unsigned int);
 int (*add_pixel) (struct _XImage *, long);
 } f;
} XImage;




typedef struct {
    int x, y;
    int width, height;
    int border_width;
    Window sibling;
    int stack_mode;
} XWindowChanges;




typedef struct {
 unsigned long pixel;
 unsigned short red, green, blue;
 char flags;
 char pad;
} XColor;






typedef struct {
    short x1, y1, x2, y2;
} XSegment;

typedef struct {
    short x, y;
} XPoint;

typedef struct {
    short x, y;
    unsigned short width, height;
} XRectangle;

typedef struct {
    short x, y;
    unsigned short width, height;
    short angle1, angle2;
} XArc;




typedef struct {
        int key_click_percent;
        int bell_percent;
        int bell_pitch;
        int bell_duration;
        int led;
        int led_mode;
        int key;
        int auto_repeat_mode;
} XKeyboardControl;



typedef struct {
        int key_click_percent;
 int bell_percent;
 unsigned int bell_pitch, bell_duration;
 unsigned long led_mask;
 int global_auto_repeat;
 char auto_repeats[32];
} XKeyboardState;



typedef struct {
        Time time;
 short x, y;
} XTimeCoord;



typedef struct {
  int max_keypermod;
  KeyCode *modifiermap;
} XModifierKeymap;
typedef struct _XDisplay Display;


struct _XPrivate;
struct _XrmHashBucketRec;

typedef struct



{
 XExtData *ext_data;
 struct _XPrivate *private1;
 int fd;
 int private2;
 int proto_major_version;
 int proto_minor_version;
 char *vendor;
        XID private3;
 XID private4;
 XID private5;
 int private6;
 XID (*resource_alloc)(
  struct _XDisplay*
 );
 int byte_order;
 int bitmap_unit;
 int bitmap_pad;
 int bitmap_bit_order;
 int nformats;
 ScreenFormat *pixmap_format;
 int private8;
 int release;
 struct _XPrivate *private9, *private10;
 int qlen;
 unsigned long last_request_read;
 unsigned long request;
 XPointer private11;
 XPointer private12;
 XPointer private13;
 XPointer private14;
 unsigned max_request_size;
 struct _XrmHashBucketRec *db;
 int (*private15)(
  struct _XDisplay*
  );
 char *display_name;
 int default_screen;
 int nscreens;
 Screen *screens;
 unsigned long motion_buffer;
 unsigned long private16;
 int min_keycode;
 int max_keycode;
 XPointer private17;
 XPointer private18;
 int private19;
 char *xdefaults;

}



*_XPrivDisplay;






typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 Window root;
 Window subwindow;
 Time time;
 int x, y;
 int x_root, y_root;
 unsigned int state;
 unsigned int keycode;
 int same_screen;
} XKeyEvent;
typedef XKeyEvent XKeyPressedEvent;
typedef XKeyEvent XKeyReleasedEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 Window root;
 Window subwindow;
 Time time;
 int x, y;
 int x_root, y_root;
 unsigned int state;
 unsigned int button;
 int same_screen;
} XButtonEvent;
typedef XButtonEvent XButtonPressedEvent;
typedef XButtonEvent XButtonReleasedEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 Window root;
 Window subwindow;
 Time time;
 int x, y;
 int x_root, y_root;
 unsigned int state;
 char is_hint;
 int same_screen;
} XMotionEvent;
typedef XMotionEvent XPointerMovedEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 Window root;
 Window subwindow;
 Time time;
 int x, y;
 int x_root, y_root;
 int mode;
 int detail;




 int same_screen;
 int focus;
 unsigned int state;
} XCrossingEvent;
typedef XCrossingEvent XEnterWindowEvent;
typedef XCrossingEvent XLeaveWindowEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 int mode;

 int detail;





} XFocusChangeEvent;
typedef XFocusChangeEvent XFocusInEvent;
typedef XFocusChangeEvent XFocusOutEvent;


typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 char key_vector[32];
} XKeymapEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 int x, y;
 int width, height;
 int count;
} XExposeEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Drawable drawable;
 int x, y;
 int width, height;
 int count;
 int major_code;
 int minor_code;
} XGraphicsExposeEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Drawable drawable;
 int major_code;
 int minor_code;
} XNoExposeEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 int state;
} XVisibilityEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window parent;
 Window window;
 int x, y;
 int width, height;
 int border_width;
 int override_redirect;
} XCreateWindowEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window event;
 Window window;
} XDestroyWindowEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window event;
 Window window;
 int from_configure;
} XUnmapEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window event;
 Window window;
 int override_redirect;
} XMapEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window parent;
 Window window;
} XMapRequestEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window event;
 Window window;
 Window parent;
 int x, y;
 int override_redirect;
} XReparentEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window event;
 Window window;
 int x, y;
 int width, height;
 int border_width;
 Window above;
 int override_redirect;
} XConfigureEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window event;
 Window window;
 int x, y;
} XGravityEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 int width, height;
} XResizeRequestEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window parent;
 Window window;
 int x, y;
 int width, height;
 int border_width;
 Window above;
 int detail;
 unsigned long value_mask;
} XConfigureRequestEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window event;
 Window window;
 int place;
} XCirculateEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window parent;
 Window window;
 int place;
} XCirculateRequestEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 Atom atom;
 Time time;
 int state;
} XPropertyEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 Atom selection;
 Time time;
} XSelectionClearEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window owner;
 Window requestor;
 Atom selection;
 Atom target;
 Atom property;
 Time time;
} XSelectionRequestEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window requestor;
 Atom selection;
 Atom target;
 Atom property;
 Time time;
} XSelectionEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 Colormap colormap;
 int _new;

 int state;
} XColormapEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 Atom message_type;
 int format;
 union {
  char b[20];
  short s[10];
  long l[5];
  } data;
} XClientMessageEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
 int request;

 int first_keycode;
 int count;
} XMappingEvent;

typedef struct {
 int type;
 Display *display;
 XID resourceid;
 unsigned long serial;
 unsigned char error_code;
 unsigned char request_code;
 unsigned char minor_code;
} XErrorEvent;

typedef struct {
 int type;
 unsigned long serial;
 int send_event;
 Display *display;
 Window window;
} XAnyEvent;







typedef struct
    {
    int type;
    unsigned long serial;
    int send_event;
    Display *display;
    int extension;
    int evtype;
    } XGenericEvent;

typedef struct {
    int type;
    unsigned long serial;
    int send_event;
    Display *display;
    int extension;
    int evtype;
    unsigned int cookie;
    void *data;
} XGenericEventCookie;





typedef union _XEvent {
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
 long pad[24];
} XEvent;







typedef struct {
    short lbearing;
    short rbearing;
    short width;
    short ascent;
    short descent;
    unsigned short attributes;
} XCharStruct;





typedef struct {
    Atom name;
    unsigned long card32;
} XFontProp;

typedef struct {
    XExtData *ext_data;
    Font fid;
    unsigned direction;
    unsigned min_char_or_byte2;
    unsigned max_char_or_byte2;
    unsigned min_byte1;
    unsigned max_byte1;
    int all_chars_exist;
    unsigned default_char;
    int n_properties;
    XFontProp *properties;
    XCharStruct min_bounds;
    XCharStruct max_bounds;
    XCharStruct *per_char;
    int ascent;
    int descent;
} XFontStruct;




typedef struct {
    char *chars;
    int nchars;
    int delta;
    Font font;
} XTextItem;

typedef struct {
    unsigned char byte1;
    unsigned char byte2;
} XChar2b;

typedef struct {
    XChar2b *chars;
    int nchars;
    int delta;
    Font font;
} XTextItem16;


typedef union { Display *display;
  GC gc;
  Visual *visual;
  Screen *screen;
  ScreenFormat *pixmap_format;
  XFontStruct *font; } XEDataObject;

typedef struct {
    XRectangle max_ink_extent;
    XRectangle max_logical_extent;
} XFontSetExtents;





typedef struct _XOM *XOM;
typedef struct _XOC *XOC, *XFontSet;

typedef struct {
    char *chars;
    int nchars;
    int delta;
    XFontSet font_set;
} XmbTextItem;

typedef struct {
    wchar_t *chars;
    int nchars;
    int delta;
    XFontSet font_set;
} XwcTextItem;
typedef struct {
    int charset_count;
    char **charset_list;
} XOMCharSetList;

typedef enum {
    XOMOrientation_LTR_TTB,
    XOMOrientation_RTL_TTB,
    XOMOrientation_TTB_LTR,
    XOMOrientation_TTB_RTL,
    XOMOrientation_Context
} XOrientation;

typedef struct {
    int num_orientation;
    XOrientation *orientation;
} XOMOrientation;

typedef struct {
    int num_font;
    XFontStruct **font_struct_list;
    char **font_name_list;
} XOMFontInfo;

typedef struct _XIM *XIM;
typedef struct _XIC *XIC;

typedef void (*XIMProc)(
    XIM,
    XPointer,
    XPointer
);

typedef int (*XICProc)(
    XIC,
    XPointer,
    XPointer
);

typedef void (*XIDProc)(
    Display*,
    XPointer,
    XPointer
);

typedef unsigned long XIMStyle;

typedef struct {
    unsigned short count_styles;
    XIMStyle *supported_styles;
} XIMStyles;
typedef void *XVaNestedList;

typedef struct {
    XPointer client_data;
    XIMProc callback;
} XIMCallback;

typedef struct {
    XPointer client_data;
    XICProc callback;
} XICCallback;

typedef unsigned long XIMFeedback;
typedef struct _XIMText {
    unsigned short length;
    XIMFeedback *feedback;
    int encoding_is_wchar;
    union {
 char *multi_byte;
 wchar_t *wide_char;
    } string;
} XIMText;

typedef unsigned long XIMPreeditState;





typedef struct _XIMPreeditStateNotifyCallbackStruct {
    XIMPreeditState state;
} XIMPreeditStateNotifyCallbackStruct;

typedef unsigned long XIMResetState;




typedef unsigned long XIMStringConversionFeedback;
typedef struct _XIMStringConversionText {
    unsigned short length;
    XIMStringConversionFeedback *feedback;
    int encoding_is_wchar;
    union {
 char *mbs;
 wchar_t *wcs;
    } string;
} XIMStringConversionText;

typedef unsigned short XIMStringConversionPosition;

typedef unsigned short XIMStringConversionType;






typedef unsigned short XIMStringConversionOperation;




typedef enum {
    XIMForwardChar, XIMBackwardChar,
    XIMForwardWord, XIMBackwardWord,
    XIMCaretUp, XIMCaretDown,
    XIMNextLine, XIMPreviousLine,
    XIMLineStart, XIMLineEnd,
    XIMAbsolutePosition,
    XIMDontChange
} XIMCaretDirection;

typedef struct _XIMStringConversionCallbackStruct {
    XIMStringConversionPosition position;
    XIMCaretDirection direction;
    XIMStringConversionOperation operation;
    unsigned short factor;
    XIMStringConversionText *text;
} XIMStringConversionCallbackStruct;

typedef struct _XIMPreeditDrawCallbackStruct {
    int caret;
    int chg_first;
    int chg_length;
    XIMText *text;
} XIMPreeditDrawCallbackStruct;

typedef enum {
    XIMIsInvisible,
    XIMIsPrimary,
    XIMIsSecondary
} XIMCaretStyle;

typedef struct _XIMPreeditCaretCallbackStruct {
    int position;
    XIMCaretDirection direction;
    XIMCaretStyle style;
} XIMPreeditCaretCallbackStruct;

typedef enum {
    XIMTextType,
    XIMBitmapType
} XIMStatusDataType;

typedef struct _XIMStatusDrawCallbackStruct {
    XIMStatusDataType type;
    union {
 XIMText *text;
 Pixmap bitmap;
    } data;
} XIMStatusDrawCallbackStruct;

typedef struct _XIMHotKeyTrigger {
    KeySym keysym;
    int modifier;
    int modifier_mask;
} XIMHotKeyTrigger;

typedef struct _XIMHotKeyTriggers {
    int num_hot_key;
    XIMHotKeyTrigger *key;
} XIMHotKeyTriggers;

typedef unsigned long XIMHotKeyState;




typedef struct {
    unsigned short count_values;
    char **supported_values;
} XIMValuesList;







extern int _Xdebug;

extern XFontStruct *XLoadQueryFont(
    Display* ,
    const char*
);

extern XFontStruct *XQueryFont(
    Display* ,
    XID
);


extern XTimeCoord *XGetMotionEvents(
    Display* ,
    Window ,
    Time ,
    Time ,
    int*
);

extern XModifierKeymap *XDeleteModifiermapEntry(
    XModifierKeymap* ,



    KeyCode ,

    int
);

extern XModifierKeymap *XGetModifierMapping(
    Display*
);

extern XModifierKeymap *XInsertModifiermapEntry(
    XModifierKeymap* ,



    KeyCode ,

    int
);

extern XModifierKeymap *XNewModifiermap(
    int
);

extern XImage *XCreateImage(
    Display* ,
    Visual* ,
    unsigned int ,
    int ,
    int ,
    char* ,
    unsigned int ,
    unsigned int ,
    int ,
    int
);
extern int XInitImage(
    XImage*
);
extern XImage *XGetImage(
    Display* ,
    Drawable ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    unsigned long ,
    int
);
extern XImage *XGetSubImage(
    Display* ,
    Drawable ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    unsigned long ,
    int ,
    XImage* ,
    int ,
    int
);




extern Display *XOpenDisplay(
    const char*
);

extern void XrmInitialize(
    void
);

extern char *XFetchBytes(
    Display* ,
    int*
);
extern char *XFetchBuffer(
    Display* ,
    int* ,
    int
);
extern char *XGetAtomName(
    Display* ,
    Atom
);
extern int XGetAtomNames(
    Display* ,
    Atom* ,
    int ,
    char**
);
extern char *XGetDefault(
    Display* ,
    const char* ,
    const char*
);
extern char *XDisplayName(
    const char*
);
extern char *XKeysymToString(
    KeySym
);

extern int (*XSynchronize(
    Display* ,
    int
))(
    Display*
);
extern int (*XSetAfterFunction(
    Display* ,
    int (*) (
      Display*
            )
))(
    Display*
);
extern Atom XInternAtom(
    Display* ,
    const char* ,
    int
);
extern int XInternAtoms(
    Display* ,
    char** ,
    int ,
    int ,
    Atom*
);
extern Colormap XCopyColormapAndFree(
    Display* ,
    Colormap
);
extern Colormap XCreateColormap(
    Display* ,
    Window ,
    Visual* ,
    int
);
extern Cursor XCreatePixmapCursor(
    Display* ,
    Pixmap ,
    Pixmap ,
    XColor* ,
    XColor* ,
    unsigned int ,
    unsigned int
);
extern Cursor XCreateGlyphCursor(
    Display* ,
    Font ,
    Font ,
    unsigned int ,
    unsigned int ,
    XColor const * ,
    XColor const *
);
extern Cursor XCreateFontCursor(
    Display* ,
    unsigned int
);
extern Font XLoadFont(
    Display* ,
    const char*
);
extern GC XCreateGC(
    Display* ,
    Drawable ,
    unsigned long ,
    XGCValues*
);
extern GContext XGContextFromGC(
    GC
);
extern void XFlushGC(
    Display* ,
    GC
);
extern Pixmap XCreatePixmap(
    Display* ,
    Drawable ,
    unsigned int ,
    unsigned int ,
    unsigned int
);
extern Pixmap XCreateBitmapFromData(
    Display* ,
    Drawable ,
    const char* ,
    unsigned int ,
    unsigned int
);
extern Pixmap XCreatePixmapFromBitmapData(
    Display* ,
    Drawable ,
    char* ,
    unsigned int ,
    unsigned int ,
    unsigned long ,
    unsigned long ,
    unsigned int
);
extern Window XCreateSimpleWindow(
    Display* ,
    Window ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    unsigned int ,
    unsigned long ,
    unsigned long
);
extern Window XGetSelectionOwner(
    Display* ,
    Atom
);
extern Window XCreateWindow(
    Display* ,
    Window ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    unsigned int ,
    int ,
    unsigned int ,
    Visual* ,
    unsigned long ,
    XSetWindowAttributes*
);
extern Colormap *XListInstalledColormaps(
    Display* ,
    Window ,
    int*
);
extern char **XListFonts(
    Display* ,
    const char* ,
    int ,
    int*
);
extern char **XListFontsWithInfo(
    Display* ,
    const char* ,
    int ,
    int* ,
    XFontStruct**
);
extern char **XGetFontPath(
    Display* ,
    int*
);
extern char **XListExtensions(
    Display* ,
    int*
);
extern Atom *XListProperties(
    Display* ,
    Window ,
    int*
);
extern XHostAddress *XListHosts(
    Display* ,
    int* ,
    int*
);
__attribute__((deprecated))
extern KeySym XKeycodeToKeysym(
    Display* ,



    KeyCode ,

    int
);
extern KeySym XLookupKeysym(
    XKeyEvent* ,
    int
);
extern KeySym *XGetKeyboardMapping(
    Display* ,



    KeyCode ,

    int ,
    int*
);
extern KeySym XStringToKeysym(
    const char*
);
extern long XMaxRequestSize(
    Display*
);
extern long XExtendedMaxRequestSize(
    Display*
);
extern char *XResourceManagerString(
    Display*
);
extern char *XScreenResourceString(
 Screen*
);
extern unsigned long XDisplayMotionBufferSize(
    Display*
);
extern VisualID XVisualIDFromVisual(
    Visual*
);



extern int XInitThreads(
    void
);

extern void XLockDisplay(
    Display*
);

extern void XUnlockDisplay(
    Display*
);



extern XExtCodes *XInitExtension(
    Display* ,
    const char*
);

extern XExtCodes *XAddExtension(
    Display*
);
extern XExtData *XFindOnExtensionList(
    XExtData** ,
    int
);
extern XExtData **XEHeadOfExtensionList(
    XEDataObject
);


extern Window XRootWindow(
    Display* ,
    int
);
extern Window XDefaultRootWindow(
    Display*
);
extern Window XRootWindowOfScreen(
    Screen*
);
extern Visual *XDefaultVisual(
    Display* ,
    int
);
extern Visual *XDefaultVisualOfScreen(
    Screen*
);
extern GC XDefaultGC(
    Display* ,
    int
);
extern GC XDefaultGCOfScreen(
    Screen*
);
extern unsigned long XBlackPixel(
    Display* ,
    int
);
extern unsigned long XWhitePixel(
    Display* ,
    int
);
extern unsigned long XAllPlanes(
    void
);
extern unsigned long XBlackPixelOfScreen(
    Screen*
);
extern unsigned long XWhitePixelOfScreen(
    Screen*
);
extern unsigned long XNextRequest(
    Display*
);
extern unsigned long XLastKnownRequestProcessed(
    Display*
);
extern char *XServerVendor(
    Display*
);
extern char *XDisplayString(
    Display*
);
extern Colormap XDefaultColormap(
    Display* ,
    int
);
extern Colormap XDefaultColormapOfScreen(
    Screen*
);
extern Display *XDisplayOfScreen(
    Screen*
);
extern Screen *XScreenOfDisplay(
    Display* ,
    int
);
extern Screen *XDefaultScreenOfDisplay(
    Display*
);
extern long XEventMaskOfScreen(
    Screen*
);

extern int XScreenNumberOfScreen(
    Screen*
);

typedef int (*XErrorHandler) (
    Display* ,
    XErrorEvent*
);

extern XErrorHandler XSetErrorHandler (
    XErrorHandler
);


typedef int (*XIOErrorHandler) (
    Display*
);

extern XIOErrorHandler XSetIOErrorHandler (
    XIOErrorHandler
);


extern XPixmapFormatValues *XListPixmapFormats(
    Display* ,
    int*
);
extern int *XListDepths(
    Display* ,
    int ,
    int*
);



extern int XReconfigureWMWindow(
    Display* ,
    Window ,
    int ,
    unsigned int ,
    XWindowChanges*
);

extern int XGetWMProtocols(
    Display* ,
    Window ,
    Atom** ,
    int*
);
extern int XSetWMProtocols(
    Display* ,
    Window ,
    Atom* ,
    int
);
extern int XIconifyWindow(
    Display* ,
    Window ,
    int
);
extern int XWithdrawWindow(
    Display* ,
    Window ,
    int
);
extern int XGetCommand(
    Display* ,
    Window ,
    char*** ,
    int*
);
extern int XGetWMColormapWindows(
    Display* ,
    Window ,
    Window** ,
    int*
);
extern int XSetWMColormapWindows(
    Display* ,
    Window ,
    Window* ,
    int
);
extern void XFreeStringList(
    char**
);
extern int XSetTransientForHint(
    Display* ,
    Window ,
    Window
);



extern int XActivateScreenSaver(
    Display*
);

extern int XAddHost(
    Display* ,
    XHostAddress*
);

extern int XAddHosts(
    Display* ,
    XHostAddress* ,
    int
);

extern int XAddToExtensionList(
    struct _XExtData** ,
    XExtData*
);

extern int XAddToSaveSet(
    Display* ,
    Window
);

extern int XAllocColor(
    Display* ,
    Colormap ,
    XColor*
);

extern int XAllocColorCells(
    Display* ,
    Colormap ,
    int ,
    unsigned long* ,
    unsigned int ,
    unsigned long* ,
    unsigned int
);

extern int XAllocColorPlanes(
    Display* ,
    Colormap ,
    int ,
    unsigned long* ,
    int ,
    int ,
    int ,
    int ,
    unsigned long* ,
    unsigned long* ,
    unsigned long*
);

extern int XAllocNamedColor(
    Display* ,
    Colormap ,
    const char* ,
    XColor* ,
    XColor*
);

extern int XAllowEvents(
    Display* ,
    int ,
    Time
);

extern int XAutoRepeatOff(
    Display*
);

extern int XAutoRepeatOn(
    Display*
);

extern int XBell(
    Display* ,
    int
);

extern int XBitmapBitOrder(
    Display*
);

extern int XBitmapPad(
    Display*
);

extern int XBitmapUnit(
    Display*
);

extern int XCellsOfScreen(
    Screen*
);

extern int XChangeActivePointerGrab(
    Display* ,
    unsigned int ,
    Cursor ,
    Time
);

extern int XChangeGC(
    Display* ,
    GC ,
    unsigned long ,
    XGCValues*
);

extern int XChangeKeyboardControl(
    Display* ,
    unsigned long ,
    XKeyboardControl*
);

extern int XChangeKeyboardMapping(
    Display* ,
    int ,
    int ,
    KeySym* ,
    int
);

extern int XChangePointerControl(
    Display* ,
    int ,
    int ,
    int ,
    int ,
    int
);

extern int XChangeProperty(
    Display* ,
    Window ,
    Atom ,
    Atom ,
    int ,
    int ,
    const unsigned char* ,
    int
);

extern int XChangeSaveSet(
    Display* ,
    Window ,
    int
);

extern int XChangeWindowAttributes(
    Display* ,
    Window ,
    unsigned long ,
    XSetWindowAttributes*
);

extern int XCheckIfEvent(
    Display* ,
    XEvent* ,
    int (*) (
        Display* ,
               XEvent* ,
               XPointer
             ) ,
    XPointer
);

extern int XCheckMaskEvent(
    Display* ,
    long ,
    XEvent*
);

extern int XCheckTypedEvent(
    Display* ,
    int ,
    XEvent*
);

extern int XCheckTypedWindowEvent(
    Display* ,
    Window ,
    int ,
    XEvent*
);

extern int XCheckWindowEvent(
    Display* ,
    Window ,
    long ,
    XEvent*
);

extern int XCirculateSubwindows(
    Display* ,
    Window ,
    int
);

extern int XCirculateSubwindowsDown(
    Display* ,
    Window
);

extern int XCirculateSubwindowsUp(
    Display* ,
    Window
);

extern int XClearArea(
    Display* ,
    Window ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    int
);

extern int XClearWindow(
    Display* ,
    Window
);

extern int XCloseDisplay(
    Display*
);

extern int XConfigureWindow(
    Display* ,
    Window ,
    unsigned int ,
    XWindowChanges*
);

extern int XConnectionNumber(
    Display*
);

extern int XConvertSelection(
    Display* ,
    Atom ,
    Atom ,
    Atom ,
    Window ,
    Time
);

extern int XCopyArea(
    Display* ,
    Drawable ,
    Drawable ,
    GC ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    int ,
    int
);

extern int XCopyGC(
    Display* ,
    GC ,
    unsigned long ,
    GC
);

extern int XCopyPlane(
    Display* ,
    Drawable ,
    Drawable ,
    GC ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    int ,
    int ,
    unsigned long
);

extern int XDefaultDepth(
    Display* ,
    int
);

extern int XDefaultDepthOfScreen(
    Screen*
);

extern int XDefaultScreen(
    Display*
);

extern int XDefineCursor(
    Display* ,
    Window ,
    Cursor
);

extern int XDeleteProperty(
    Display* ,
    Window ,
    Atom
);

extern int XDestroyWindow(
    Display* ,
    Window
);

extern int XDestroySubwindows(
    Display* ,
    Window
);

extern int XDoesBackingStore(
    Screen*
);

extern int XDoesSaveUnders(
    Screen*
);

extern int XDisableAccessControl(
    Display*
);


extern int XDisplayCells(
    Display* ,
    int
);

extern int XDisplayHeight(
    Display* ,
    int
);

extern int XDisplayHeightMM(
    Display* ,
    int
);

extern int XDisplayKeycodes(
    Display* ,
    int* ,
    int*
);

extern int XDisplayPlanes(
    Display* ,
    int
);

extern int XDisplayWidth(
    Display* ,
    int
);

extern int XDisplayWidthMM(
    Display* ,
    int
);

extern int XDrawArc(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    int ,
    int
);

extern int XDrawArcs(
    Display* ,
    Drawable ,
    GC ,
    XArc* ,
    int
);

extern int XDrawImageString(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    const char* ,
    int
);

extern int XDrawImageString16(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    const XChar2b* ,
    int
);

extern int XDrawLine(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    int ,
    int
);

extern int XDrawLines(
    Display* ,
    Drawable ,
    GC ,
    XPoint* ,
    int ,
    int
);

extern int XDrawPoint(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int
);

extern int XDrawPoints(
    Display* ,
    Drawable ,
    GC ,
    XPoint* ,
    int ,
    int
);

extern int XDrawRectangle(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    unsigned int ,
    unsigned int
);

extern int XDrawRectangles(
    Display* ,
    Drawable ,
    GC ,
    XRectangle* ,
    int
);

extern int XDrawSegments(
    Display* ,
    Drawable ,
    GC ,
    XSegment* ,
    int
);

extern int XDrawString(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    const char* ,
    int
);

extern int XDrawString16(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    const XChar2b* ,
    int
);

extern int XDrawText(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    XTextItem* ,
    int
);

extern int XDrawText16(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    XTextItem16* ,
    int
);

extern int XEnableAccessControl(
    Display*
);

extern int XEventsQueued(
    Display* ,
    int
);

extern int XFetchName(
    Display* ,
    Window ,
    char**
);

extern int XFillArc(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    int ,
    int
);

extern int XFillArcs(
    Display* ,
    Drawable ,
    GC ,
    XArc* ,
    int
);

extern int XFillPolygon(
    Display* ,
    Drawable ,
    GC ,
    XPoint* ,
    int ,
    int ,
    int
);

extern int XFillRectangle(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    unsigned int ,
    unsigned int
);

extern int XFillRectangles(
    Display* ,
    Drawable ,
    GC ,
    XRectangle* ,
    int
);

extern int XFlush(
    Display*
);

extern int XForceScreenSaver(
    Display* ,
    int
);

extern int XFree(
    void*
);

extern int XFreeColormap(
    Display* ,
    Colormap
);

extern int XFreeColors(
    Display* ,
    Colormap ,
    unsigned long* ,
    int ,
    unsigned long
);

extern int XFreeCursor(
    Display* ,
    Cursor
);

extern int XFreeExtensionList(
    char**
);

extern int XFreeFont(
    Display* ,
    XFontStruct*
);

extern int XFreeFontInfo(
    char** ,
    XFontStruct* ,
    int
);

extern int XFreeFontNames(
    char**
);

extern int XFreeFontPath(
    char**
);

extern int XFreeGC(
    Display* ,
    GC
);

extern int XFreeModifiermap(
    XModifierKeymap*
);

extern int XFreePixmap(
    Display* ,
    Pixmap
);

extern int XGeometry(
    Display* ,
    int ,
    const char* ,
    const char* ,
    unsigned int ,
    unsigned int ,
    unsigned int ,
    int ,
    int ,
    int* ,
    int* ,
    int* ,
    int*
);

extern int XGetErrorDatabaseText(
    Display* ,
    const char* ,
    const char* ,
    const char* ,
    char* ,
    int
);

extern int XGetErrorText(
    Display* ,
    int ,
    char* ,
    int
);

extern int XGetFontProperty(
    XFontStruct* ,
    Atom ,
    unsigned long*
);

extern int XGetGCValues(
    Display* ,
    GC ,
    unsigned long ,
    XGCValues*
);

extern int XGetGeometry(
    Display* ,
    Drawable ,
    Window* ,
    int* ,
    int* ,
    unsigned int* ,
    unsigned int* ,
    unsigned int* ,
    unsigned int*
);

extern int XGetIconName(
    Display* ,
    Window ,
    char**
);

extern int XGetInputFocus(
    Display* ,
    Window* ,
    int*
);

extern int XGetKeyboardControl(
    Display* ,
    XKeyboardState*
);

extern int XGetPointerControl(
    Display* ,
    int* ,
    int* ,
    int*
);

extern int XGetPointerMapping(
    Display* ,
    unsigned char* ,
    int
);

extern int XGetScreenSaver(
    Display* ,
    int* ,
    int* ,
    int* ,
    int*
);

extern int XGetTransientForHint(
    Display* ,
    Window ,
    Window*
);

extern int XGetWindowProperty(
    Display* ,
    Window ,
    Atom ,
    long ,
    long ,
    int ,
    Atom ,
    Atom* ,
    int* ,
    unsigned long* ,
    unsigned long* ,
    unsigned char**
);

extern int XGetWindowAttributes(
    Display* ,
    Window ,
    XWindowAttributes*
);

extern int XGrabButton(
    Display* ,
    unsigned int ,
    unsigned int ,
    Window ,
    int ,
    unsigned int ,
    int ,
    int ,
    Window ,
    Cursor
);

extern int XGrabKey(
    Display* ,
    int ,
    unsigned int ,
    Window ,
    int ,
    int ,
    int
);

extern int XGrabKeyboard(
    Display* ,
    Window ,
    int ,
    int ,
    int ,
    Time
);

extern int XGrabPointer(
    Display* ,
    Window ,
    int ,
    unsigned int ,
    int ,
    int ,
    Window ,
    Cursor ,
    Time
);

extern int XGrabServer(
    Display*
);

extern int XHeightMMOfScreen(
    Screen*
);

extern int XHeightOfScreen(
    Screen*
);

extern int XIfEvent(
    Display* ,
    XEvent* ,
    int (*) (
        Display* ,
               XEvent* ,
               XPointer
             ) ,
    XPointer
);

extern int XImageByteOrder(
    Display*
);

extern int XInstallColormap(
    Display* ,
    Colormap
);

extern KeyCode XKeysymToKeycode(
    Display* ,
    KeySym
);

extern int XKillClient(
    Display* ,
    XID
);

extern int XLookupColor(
    Display* ,
    Colormap ,
    const char* ,
    XColor* ,
    XColor*
);

extern int XLowerWindow(
    Display* ,
    Window
);

extern int XMapRaised(
    Display* ,
    Window
);

extern int XMapSubwindows(
    Display* ,
    Window
);

extern int XMapWindow(
    Display* ,
    Window
);

extern int XMaskEvent(
    Display* ,
    long ,
    XEvent*
);

extern int XMaxCmapsOfScreen(
    Screen*
);

extern int XMinCmapsOfScreen(
    Screen*
);

extern int XMoveResizeWindow(
    Display* ,
    Window ,
    int ,
    int ,
    unsigned int ,
    unsigned int
);

extern int XMoveWindow(
    Display* ,
    Window ,
    int ,
    int
);

extern int XNextEvent(
    Display* ,
    XEvent*
);

extern int XNoOp(
    Display*
);

extern int XParseColor(
    Display* ,
    Colormap ,
    const char* ,
    XColor*
);

extern int XParseGeometry(
    const char* ,
    int* ,
    int* ,
    unsigned int* ,
    unsigned int*
);

extern int XPeekEvent(
    Display* ,
    XEvent*
);

extern int XPeekIfEvent(
    Display* ,
    XEvent* ,
    int (*) (
        Display* ,
               XEvent* ,
               XPointer
             ) ,
    XPointer
);

extern int XPending(
    Display*
);

extern int XPlanesOfScreen(
    Screen*
);

extern int XProtocolRevision(
    Display*
);

extern int XProtocolVersion(
    Display*
);


extern int XPutBackEvent(
    Display* ,
    XEvent*
);

extern int XPutImage(
    Display* ,
    Drawable ,
    GC ,
    XImage* ,
    int ,
    int ,
    int ,
    int ,
    unsigned int ,
    unsigned int
);

extern int XQLength(
    Display*
);

extern int XQueryBestCursor(
    Display* ,
    Drawable ,
    unsigned int ,
    unsigned int ,
    unsigned int* ,
    unsigned int*
);

extern int XQueryBestSize(
    Display* ,
    int ,
    Drawable ,
    unsigned int ,
    unsigned int ,
    unsigned int* ,
    unsigned int*
);

extern int XQueryBestStipple(
    Display* ,
    Drawable ,
    unsigned int ,
    unsigned int ,
    unsigned int* ,
    unsigned int*
);

extern int XQueryBestTile(
    Display* ,
    Drawable ,
    unsigned int ,
    unsigned int ,
    unsigned int* ,
    unsigned int*
);

extern int XQueryColor(
    Display* ,
    Colormap ,
    XColor*
);

extern int XQueryColors(
    Display* ,
    Colormap ,
    XColor* ,
    int
);

extern int XQueryExtension(
    Display* ,
    const char* ,
    int* ,
    int* ,
    int*
);

extern int XQueryKeymap(
    Display* ,
    char [32]
);

extern int XQueryPointer(
    Display* ,
    Window ,
    Window* ,
    Window* ,
    int* ,
    int* ,
    int* ,
    int* ,
    unsigned int*
);

extern int XQueryTextExtents(
    Display* ,
    XID ,
    const char* ,
    int ,
    int* ,
    int* ,
    int* ,
    XCharStruct*
);

extern int XQueryTextExtents16(
    Display* ,
    XID ,
    const XChar2b* ,
    int ,
    int* ,
    int* ,
    int* ,
    XCharStruct*
);

extern int XQueryTree(
    Display* ,
    Window ,
    Window* ,
    Window* ,
    Window** ,
    unsigned int*
);

extern int XRaiseWindow(
    Display* ,
    Window
);

extern int XReadBitmapFile(
    Display* ,
    Drawable ,
    const char* ,
    unsigned int* ,
    unsigned int* ,
    Pixmap* ,
    int* ,
    int*
);

extern int XReadBitmapFileData(
    const char* ,
    unsigned int* ,
    unsigned int* ,
    unsigned char** ,
    int* ,
    int*
);

extern int XRebindKeysym(
    Display* ,
    KeySym ,
    KeySym* ,
    int ,
    const unsigned char* ,
    int
);

extern int XRecolorCursor(
    Display* ,
    Cursor ,
    XColor* ,
    XColor*
);

extern int XRefreshKeyboardMapping(
    XMappingEvent*
);

extern int XRemoveFromSaveSet(
    Display* ,
    Window
);

extern int XRemoveHost(
    Display* ,
    XHostAddress*
);

extern int XRemoveHosts(
    Display* ,
    XHostAddress* ,
    int
);

extern int XReparentWindow(
    Display* ,
    Window ,
    Window ,
    int ,
    int
);

extern int XResetScreenSaver(
    Display*
);

extern int XResizeWindow(
    Display* ,
    Window ,
    unsigned int ,
    unsigned int
);

extern int XRestackWindows(
    Display* ,
    Window* ,
    int
);

extern int XRotateBuffers(
    Display* ,
    int
);

extern int XRotateWindowProperties(
    Display* ,
    Window ,
    Atom* ,
    int ,
    int
);

extern int XScreenCount(
    Display*
);

extern int XSelectInput(
    Display* ,
    Window ,
    long
);

extern int XSendEvent(
    Display* ,
    Window ,
    int ,
    long ,
    XEvent*
);

extern int XSetAccessControl(
    Display* ,
    int
);

extern int XSetArcMode(
    Display* ,
    GC ,
    int
);

extern int XSetBackground(
    Display* ,
    GC ,
    unsigned long
);

extern int XSetClipMask(
    Display* ,
    GC ,
    Pixmap
);

extern int XSetClipOrigin(
    Display* ,
    GC ,
    int ,
    int
);

extern int XSetClipRectangles(
    Display* ,
    GC ,
    int ,
    int ,
    XRectangle* ,
    int ,
    int
);

extern int XSetCloseDownMode(
    Display* ,
    int
);

extern int XSetCommand(
    Display* ,
    Window ,
    char** ,
    int
);

extern int XSetDashes(
    Display* ,
    GC ,
    int ,
    const char* ,
    int
);

extern int XSetFillRule(
    Display* ,
    GC ,
    int
);

extern int XSetFillStyle(
    Display* ,
    GC ,
    int
);

extern int XSetFont(
    Display* ,
    GC ,
    Font
);

extern int XSetFontPath(
    Display* ,
    char** ,
    int
);

extern int XSetForeground(
    Display* ,
    GC ,
    unsigned long
);

extern int XSetFunction(
    Display* ,
    GC ,
    int
);

extern int XSetGraphicsExposures(
    Display* ,
    GC ,
    int
);

extern int XSetIconName(
    Display* ,
    Window ,
    const char*
);

extern int XSetInputFocus(
    Display* ,
    Window ,
    int ,
    Time
);

extern int XSetLineAttributes(
    Display* ,
    GC ,
    unsigned int ,
    int ,
    int ,
    int
);

extern int XSetModifierMapping(
    Display* ,
    XModifierKeymap*
);

extern int XSetPlaneMask(
    Display* ,
    GC ,
    unsigned long
);

extern int XSetPointerMapping(
    Display* ,
    const unsigned char* ,
    int
);

extern int XSetScreenSaver(
    Display* ,
    int ,
    int ,
    int ,
    int
);

extern int XSetSelectionOwner(
    Display* ,
    Atom ,
    Window ,
    Time
);

extern int XSetState(
    Display* ,
    GC ,
    unsigned long ,
    unsigned long ,
    int ,
    unsigned long
);

extern int XSetStipple(
    Display* ,
    GC ,
    Pixmap
);

extern int XSetSubwindowMode(
    Display* ,
    GC ,
    int
);

extern int XSetTSOrigin(
    Display* ,
    GC ,
    int ,
    int
);

extern int XSetTile(
    Display* ,
    GC ,
    Pixmap
);

extern int XSetWindowBackground(
    Display* ,
    Window ,
    unsigned long
);

extern int XSetWindowBackgroundPixmap(
    Display* ,
    Window ,
    Pixmap
);

extern int XSetWindowBorder(
    Display* ,
    Window ,
    unsigned long
);

extern int XSetWindowBorderPixmap(
    Display* ,
    Window ,
    Pixmap
);

extern int XSetWindowBorderWidth(
    Display* ,
    Window ,
    unsigned int
);

extern int XSetWindowColormap(
    Display* ,
    Window ,
    Colormap
);

extern int XStoreBuffer(
    Display* ,
    const char* ,
    int ,
    int
);

extern int XStoreBytes(
    Display* ,
    const char* ,
    int
);

extern int XStoreColor(
    Display* ,
    Colormap ,
    XColor*
);

extern int XStoreColors(
    Display* ,
    Colormap ,
    XColor* ,
    int
);

extern int XStoreName(
    Display* ,
    Window ,
    const char*
);

extern int XStoreNamedColor(
    Display* ,
    Colormap ,
    const char* ,
    unsigned long ,
    int
);

extern int XSync(
    Display* ,
    int
);

extern int XTextExtents(
    XFontStruct* ,
    const char* ,
    int ,
    int* ,
    int* ,
    int* ,
    XCharStruct*
);

extern int XTextExtents16(
    XFontStruct* ,
    const XChar2b* ,
    int ,
    int* ,
    int* ,
    int* ,
    XCharStruct*
);

extern int XTextWidth(
    XFontStruct* ,
    const char* ,
    int
);

extern int XTextWidth16(
    XFontStruct* ,
    const XChar2b* ,
    int
);

extern int XTranslateCoordinates(
    Display* ,
    Window ,
    Window ,
    int ,
    int ,
    int* ,
    int* ,
    Window*
);

extern int XUndefineCursor(
    Display* ,
    Window
);

extern int XUngrabButton(
    Display* ,
    unsigned int ,
    unsigned int ,
    Window
);

extern int XUngrabKey(
    Display* ,
    int ,
    unsigned int ,
    Window
);

extern int XUngrabKeyboard(
    Display* ,
    Time
);

extern int XUngrabPointer(
    Display* ,
    Time
);

extern int XUngrabServer(
    Display*
);

extern int XUninstallColormap(
    Display* ,
    Colormap
);

extern int XUnloadFont(
    Display* ,
    Font
);

extern int XUnmapSubwindows(
    Display* ,
    Window
);

extern int XUnmapWindow(
    Display* ,
    Window
);

extern int XVendorRelease(
    Display*
);

extern int XWarpPointer(
    Display* ,
    Window ,
    Window ,
    int ,
    int ,
    unsigned int ,
    unsigned int ,
    int ,
    int
);

extern int XWidthMMOfScreen(
    Screen*
);

extern int XWidthOfScreen(
    Screen*
);

extern int XWindowEvent(
    Display* ,
    Window ,
    long ,
    XEvent*
);

extern int XWriteBitmapFile(
    Display* ,
    const char* ,
    Pixmap ,
    unsigned int ,
    unsigned int ,
    int ,
    int
);

extern int XSupportsLocale (void);

extern char *XSetLocaleModifiers(
    const char*
);

extern XOM XOpenOM(
    Display* ,
    struct _XrmHashBucketRec* ,
    const char* ,
    const char*
);

extern int XCloseOM(
    XOM
);

extern char *XSetOMValues(
    XOM ,
    ...
) __attribute__ ((__sentinel__(0)));

extern char *XGetOMValues(
    XOM ,
    ...
) __attribute__ ((__sentinel__(0)));

extern Display *XDisplayOfOM(
    XOM
);

extern char *XLocaleOfOM(
    XOM
);

extern XOC XCreateOC(
    XOM ,
    ...
) __attribute__ ((__sentinel__(0)));

extern void XDestroyOC(
    XOC
);

extern XOM XOMOfOC(
    XOC
);

extern char *XSetOCValues(
    XOC ,
    ...
) __attribute__ ((__sentinel__(0)));

extern char *XGetOCValues(
    XOC ,
    ...
) __attribute__ ((__sentinel__(0)));

extern XFontSet XCreateFontSet(
    Display* ,
    const char* ,
    char*** ,
    int* ,
    char**
);

extern void XFreeFontSet(
    Display* ,
    XFontSet
);

extern int XFontsOfFontSet(
    XFontSet ,
    XFontStruct*** ,
    char***
);

extern char *XBaseFontNameListOfFontSet(
    XFontSet
);

extern char *XLocaleOfFontSet(
    XFontSet
);

extern int XContextDependentDrawing(
    XFontSet
);

extern int XDirectionalDependentDrawing(
    XFontSet
);

extern int XContextualDrawing(
    XFontSet
);

extern XFontSetExtents *XExtentsOfFontSet(
    XFontSet
);

extern int XmbTextEscapement(
    XFontSet ,
    const char* ,
    int
);

extern int XwcTextEscapement(
    XFontSet ,
    const wchar_t* ,
    int
);

extern int Xutf8TextEscapement(
    XFontSet ,
    const char* ,
    int
);

extern int XmbTextExtents(
    XFontSet ,
    const char* ,
    int ,
    XRectangle* ,
    XRectangle*
);

extern int XwcTextExtents(
    XFontSet ,
    const wchar_t* ,
    int ,
    XRectangle* ,
    XRectangle*
);

extern int Xutf8TextExtents(
    XFontSet ,
    const char* ,
    int ,
    XRectangle* ,
    XRectangle*
);

extern int XmbTextPerCharExtents(
    XFontSet ,
    const char* ,
    int ,
    XRectangle* ,
    XRectangle* ,
    int ,
    int* ,
    XRectangle* ,
    XRectangle*
);

extern int XwcTextPerCharExtents(
    XFontSet ,
    const wchar_t* ,
    int ,
    XRectangle* ,
    XRectangle* ,
    int ,
    int* ,
    XRectangle* ,
    XRectangle*
);

extern int Xutf8TextPerCharExtents(
    XFontSet ,
    const char* ,
    int ,
    XRectangle* ,
    XRectangle* ,
    int ,
    int* ,
    XRectangle* ,
    XRectangle*
);

extern void XmbDrawText(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    XmbTextItem* ,
    int
);

extern void XwcDrawText(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    XwcTextItem* ,
    int
);

extern void Xutf8DrawText(
    Display* ,
    Drawable ,
    GC ,
    int ,
    int ,
    XmbTextItem* ,
    int
);

extern void XmbDrawString(
    Display* ,
    Drawable ,
    XFontSet ,
    GC ,
    int ,
    int ,
    const char* ,
    int
);

extern void XwcDrawString(
    Display* ,
    Drawable ,
    XFontSet ,
    GC ,
    int ,
    int ,
    const wchar_t* ,
    int
);

extern void Xutf8DrawString(
    Display* ,
    Drawable ,
    XFontSet ,
    GC ,
    int ,
    int ,
    const char* ,
    int
);

extern void XmbDrawImageString(
    Display* ,
    Drawable ,
    XFontSet ,
    GC ,
    int ,
    int ,
    const char* ,
    int
);

extern void XwcDrawImageString(
    Display* ,
    Drawable ,
    XFontSet ,
    GC ,
    int ,
    int ,
    const wchar_t* ,
    int
);

extern void Xutf8DrawImageString(
    Display* ,
    Drawable ,
    XFontSet ,
    GC ,
    int ,
    int ,
    const char* ,
    int
);

extern XIM XOpenIM(
    Display* ,
    struct _XrmHashBucketRec* ,
    char* ,
    char*
);

extern int XCloseIM(
    XIM
);

extern char *XGetIMValues(
    XIM , ...
) __attribute__ ((__sentinel__(0)));

extern char *XSetIMValues(
    XIM , ...
) __attribute__ ((__sentinel__(0)));

extern Display *XDisplayOfIM(
    XIM
);

extern char *XLocaleOfIM(
    XIM
);

extern XIC XCreateIC(
    XIM , ...
) __attribute__ ((__sentinel__(0)));

extern void XDestroyIC(
    XIC
);

extern void XSetICFocus(
    XIC
);

extern void XUnsetICFocus(
    XIC
);

extern wchar_t *XwcResetIC(
    XIC
);

extern char *XmbResetIC(
    XIC
);

extern char *Xutf8ResetIC(
    XIC
);

extern char *XSetICValues(
    XIC , ...
) __attribute__ ((__sentinel__(0)));

extern char *XGetICValues(
    XIC , ...
) __attribute__ ((__sentinel__(0)));

extern XIM XIMOfIC(
    XIC
);

extern int XFilterEvent(
    XEvent* ,
    Window
);

extern int XmbLookupString(
    XIC ,
    XKeyPressedEvent* ,
    char* ,
    int ,
    KeySym* ,
    int*
);

extern int XwcLookupString(
    XIC ,
    XKeyPressedEvent* ,
    wchar_t* ,
    int ,
    KeySym* ,
    int*
);

extern int Xutf8LookupString(
    XIC ,
    XKeyPressedEvent* ,
    char* ,
    int ,
    KeySym* ,
    int*
);

extern XVaNestedList XVaCreateNestedList(
    int , ...
) __attribute__ ((__sentinel__(0)));



extern int XRegisterIMInstantiateCallback(
    Display* ,
    struct _XrmHashBucketRec* ,
    char* ,
    char* ,
    XIDProc ,
    XPointer
);

extern int XUnregisterIMInstantiateCallback(
    Display* ,
    struct _XrmHashBucketRec* ,
    char* ,
    char* ,
    XIDProc ,
    XPointer
);

typedef void (*XConnectionWatchProc)(
    Display* ,
    XPointer ,
    int ,
    int ,
    XPointer*
);


extern int XInternalConnectionNumbers(
    Display* ,
    int** ,
    int*
);

extern void XProcessInternalConnection(
    Display* ,
    int
);

extern int XAddConnectionWatch(
    Display* ,
    XConnectionWatchProc ,
    XPointer
);

extern void XRemoveConnectionWatch(
    Display* ,
    XConnectionWatchProc ,
    XPointer
);

extern void XSetAuthorization(
    char * ,
    int ,
    char * ,
    int
);

extern int _Xmbtowc(
    wchar_t * ,




    char * ,
    int

);

extern int _Xwctomb(
    char * ,
    wchar_t
);

extern int XGetEventData(
    Display* ,
    XGenericEventCookie*
);

extern void XFreeEventData(
    Display* ,
    XGenericEventCookie*
);


typedef struct {
     long flags;
 int x, y;
 int width, height;
 int min_width, min_height;
 int max_width, max_height;
     int width_inc, height_inc;
 struct {
  int x;
  int y;
 } min_aspect, max_aspect;
 int base_width, base_height;
 int win_gravity;
} XSizeHints;
typedef struct {
 long flags;
 int input;

 int initial_state;
 Pixmap icon_pixmap;
 Window icon_window;
 int icon_x, icon_y;
 Pixmap icon_mask;
 XID window_group;

} XWMHints;
typedef struct {
    unsigned char *value;
    Atom encoding;
    int format;
    unsigned long nitems;
} XTextProperty;





typedef enum {
    XStringStyle,
    XCompoundTextStyle,
    XTextStyle,
    XStdICCTextStyle,

    XUTF8StringStyle
} XICCEncodingStyle;

typedef struct {
 int min_width, min_height;
 int max_width, max_height;
 int width_inc, height_inc;
} XIconSize;

typedef struct {
 char *res_name;
 char *res_class;
} XClassHint;
typedef struct _XComposeStatus {
    XPointer compose_ptr;
    int chars_matched;
} XComposeStatus;
typedef struct _XRegion *Region;
typedef struct {
  Visual *visual;
  VisualID visualid;
  int screen;
  int depth;
  int _class;
  unsigned long red_mask;
  unsigned long green_mask;
  unsigned long blue_mask;
  int colormap_size;
  int bits_per_rgb;
} XVisualInfo;
typedef struct {
 Colormap colormap;
 unsigned long red_max;
 unsigned long red_mult;
 unsigned long green_max;
 unsigned long green_mult;
 unsigned long blue_max;
 unsigned long blue_mult;
 unsigned long base_pixel;
 VisualID visualid;
 XID killid;
} XStandardColormap;
typedef int XContext;








extern XClassHint *XAllocClassHint (
    void
);

extern XIconSize *XAllocIconSize (
    void
);

extern XSizeHints *XAllocSizeHints (
    void
);

extern XStandardColormap *XAllocStandardColormap (
    void
);

extern XWMHints *XAllocWMHints (
    void
);

extern int XClipBox(
    Region ,
    XRectangle*
);

extern Region XCreateRegion(
    void
);

extern const char *XDefaultString (void);

extern int XDeleteContext(
    Display* ,
    XID ,
    XContext
);

extern int XDestroyRegion(
    Region
);

extern int XEmptyRegion(
    Region
);

extern int XEqualRegion(
    Region ,
    Region
);

extern int XFindContext(
    Display* ,
    XID ,
    XContext ,
    XPointer*
);

extern int XGetClassHint(
    Display* ,
    Window ,
    XClassHint*
);

extern int XGetIconSizes(
    Display* ,
    Window ,
    XIconSize** ,
    int*
);

extern int XGetNormalHints(
    Display* ,
    Window ,
    XSizeHints*
);

extern int XGetRGBColormaps(
    Display* ,
    Window ,
    XStandardColormap** ,
    int* ,
    Atom
);

extern int XGetSizeHints(
    Display* ,
    Window ,
    XSizeHints* ,
    Atom
);

extern int XGetStandardColormap(
    Display* ,
    Window ,
    XStandardColormap* ,
    Atom
);

extern int XGetTextProperty(
    Display* ,
    Window ,
    XTextProperty* ,
    Atom
);

extern XVisualInfo *XGetVisualInfo(
    Display* ,
    long ,
    XVisualInfo* ,
    int*
);

extern int XGetWMClientMachine(
    Display* ,
    Window ,
    XTextProperty*
);

extern XWMHints *XGetWMHints(
    Display* ,
    Window
);

extern int XGetWMIconName(
    Display* ,
    Window ,
    XTextProperty*
);

extern int XGetWMName(
    Display* ,
    Window ,
    XTextProperty*
);

extern int XGetWMNormalHints(
    Display* ,
    Window ,
    XSizeHints* ,
    long*
);

extern int XGetWMSizeHints(
    Display* ,
    Window ,
    XSizeHints* ,
    long* ,
    Atom
);

extern int XGetZoomHints(
    Display* ,
    Window ,
    XSizeHints*
);

extern int XIntersectRegion(
    Region ,
    Region ,
    Region
);

extern void XConvertCase(
    KeySym ,
    KeySym* ,
    KeySym*
);

extern int XLookupString(
    XKeyEvent* ,
    char* ,
    int ,
    KeySym* ,
    XComposeStatus*
);

extern int XMatchVisualInfo(
    Display* ,
    int ,
    int ,
    int ,
    XVisualInfo*
);

extern int XOffsetRegion(
    Region ,
    int ,
    int
);

extern int XPointInRegion(
    Region ,
    int ,
    int
);

extern Region XPolygonRegion(
    XPoint* ,
    int ,
    int
);

extern int XRectInRegion(
    Region ,
    int ,
    int ,
    unsigned int ,
    unsigned int
);

extern int XSaveContext(
    Display* ,
    XID ,
    XContext ,
    const char*
);

extern int XSetClassHint(
    Display* ,
    Window ,
    XClassHint*
);

extern int XSetIconSizes(
    Display* ,
    Window ,
    XIconSize* ,
    int
);

extern int XSetNormalHints(
    Display* ,
    Window ,
    XSizeHints*
);

extern void XSetRGBColormaps(
    Display* ,
    Window ,
    XStandardColormap* ,
    int ,
    Atom
);

extern int XSetSizeHints(
    Display* ,
    Window ,
    XSizeHints* ,
    Atom
);

extern int XSetStandardProperties(
    Display* ,
    Window ,
    const char* ,
    const char* ,
    Pixmap ,
    char** ,
    int ,
    XSizeHints*
);

extern void XSetTextProperty(
    Display* ,
    Window ,
    XTextProperty* ,
    Atom
);

extern void XSetWMClientMachine(
    Display* ,
    Window ,
    XTextProperty*
);

extern int XSetWMHints(
    Display* ,
    Window ,
    XWMHints*
);

extern void XSetWMIconName(
    Display* ,
    Window ,
    XTextProperty*
);

extern void XSetWMName(
    Display* ,
    Window ,
    XTextProperty*
);

extern void XSetWMNormalHints(
    Display* ,
    Window ,
    XSizeHints*
);

extern void XSetWMProperties(
    Display* ,
    Window ,
    XTextProperty* ,
    XTextProperty* ,
    char** ,
    int ,
    XSizeHints* ,
    XWMHints* ,
    XClassHint*
);

extern void XmbSetWMProperties(
    Display* ,
    Window ,
    const char* ,
    const char* ,
    char** ,
    int ,
    XSizeHints* ,
    XWMHints* ,
    XClassHint*
);

extern void Xutf8SetWMProperties(
    Display* ,
    Window ,
    const char* ,
    const char* ,
    char** ,
    int ,
    XSizeHints* ,
    XWMHints* ,
    XClassHint*
);

extern void XSetWMSizeHints(
    Display* ,
    Window ,
    XSizeHints* ,
    Atom
);

extern int XSetRegion(
    Display* ,
    GC ,
    Region
);

extern void XSetStandardColormap(
    Display* ,
    Window ,
    XStandardColormap* ,
    Atom
);

extern int XSetZoomHints(
    Display* ,
    Window ,
    XSizeHints*
);

extern int XShrinkRegion(
    Region ,
    int ,
    int
);

extern int XStringListToTextProperty(
    char** ,
    int ,
    XTextProperty*
);

extern int XSubtractRegion(
    Region ,
    Region ,
    Region
);

extern int XmbTextListToTextProperty(
    Display* display,
    char** list,
    int count,
    XICCEncodingStyle style,
    XTextProperty* text_prop_return
);

extern int XwcTextListToTextProperty(
    Display* display,
    wchar_t** list,
    int count,
    XICCEncodingStyle style,
    XTextProperty* text_prop_return
);

extern int Xutf8TextListToTextProperty(
    Display* display,
    char** list,
    int count,
    XICCEncodingStyle style,
    XTextProperty* text_prop_return
);

extern void XwcFreeStringList(
    wchar_t** list
);

extern int XTextPropertyToStringList(
    XTextProperty* ,
    char*** ,
    int*
);

extern int XmbTextPropertyToTextList(
    Display* display,
    const XTextProperty* text_prop,
    char*** list_return,
    int* count_return
);

extern int XwcTextPropertyToTextList(
    Display* display,
    const XTextProperty* text_prop,
    wchar_t*** list_return,
    int* count_return
);

extern int Xutf8TextPropertyToTextList(
    Display* display,
    const XTextProperty* text_prop,
    char*** list_return,
    int* count_return
);

extern int XUnionRectWithRegion(
    XRectangle* ,
    Region ,
    Region
);

extern int XUnionRegion(
    Region ,
    Region ,
    Region
);

extern int XWMGeometry(
    Display* ,
    int ,
    const char* ,
    const char* ,
    unsigned int ,
    XSizeHints* ,
    int* ,
    int* ,
    int* ,
    int* ,
    int*
);

extern int XXorRegion(
    Region ,
    Region ,
    Region
);










extern char *Xpermalloc(
    unsigned int
);







typedef int XrmQuark, *XrmQuarkList;


typedef char *XrmString;



extern XrmQuark XrmStringToQuark(
    const char*
);

extern XrmQuark XrmPermStringToQuark(
    const char*
);


extern XrmString XrmQuarkToString(
    XrmQuark
);

extern XrmQuark XrmUniqueQuark(
    void
);
typedef enum {XrmBindTightly, XrmBindLoosely} XrmBinding, *XrmBindingList;

extern void XrmStringToQuarkList(
    const char* ,
    XrmQuarkList
);

extern void XrmStringToBindingQuarkList(
    const char* ,
    XrmBindingList ,
    XrmQuarkList
);







typedef XrmQuark XrmName;
typedef XrmQuarkList XrmNameList;
 
typedef XrmQuark XrmClass;
typedef XrmQuarkList XrmClassList;
typedef XrmQuark XrmRepresentation;



typedef struct {
    unsigned int size;
    XPointer addr;
} XrmValue, *XrmValuePtr;
typedef struct _XrmHashBucketRec *XrmHashBucket;
typedef XrmHashBucket *XrmHashTable;
typedef XrmHashTable XrmSearchList[];
typedef struct _XrmHashBucketRec *XrmDatabase;


extern void XrmDestroyDatabase(
    XrmDatabase
);

extern void XrmQPutResource(
    XrmDatabase* ,
    XrmBindingList ,
    XrmQuarkList ,
    XrmRepresentation ,
    XrmValue*
);

extern void XrmPutResource(
    XrmDatabase* ,
    const char* ,
    const char* ,
    XrmValue*
);

extern void XrmQPutStringResource(
    XrmDatabase* ,
    XrmBindingList ,
    XrmQuarkList ,
    const char*
);

extern void XrmPutStringResource(
    XrmDatabase* ,
    const char* ,
    const char*
);

extern void XrmPutLineResource(
    XrmDatabase* ,
    const char*
);

extern int XrmQGetResource(
    XrmDatabase ,
    XrmNameList ,
    XrmClassList ,
    XrmRepresentation* ,
    XrmValue*
);

extern int XrmGetResource(
    XrmDatabase ,
    const char* ,
    const char* ,
    char** ,
    XrmValue*
);

extern int XrmQGetSearchList(
    XrmDatabase ,
    XrmNameList ,
    XrmClassList ,
    XrmSearchList ,
    int
);

extern int XrmQGetSearchResource(
    XrmSearchList ,
    XrmName ,
    XrmClass ,
    XrmRepresentation* ,
    XrmValue*
);
extern void XrmSetDatabase(
    Display* ,
    XrmDatabase
);

extern XrmDatabase XrmGetDatabase(
    Display*
);



extern XrmDatabase XrmGetFileDatabase(
    const char*
);

extern int XrmCombineFileDatabase(
    const char* ,
    XrmDatabase* ,
    int
);

extern XrmDatabase XrmGetStringDatabase(
    const char*
);

extern void XrmPutFileDatabase(
    XrmDatabase ,
    const char*
);

extern void XrmMergeDatabases(
    XrmDatabase ,
    XrmDatabase*
);

extern void XrmCombineDatabase(
    XrmDatabase ,
    XrmDatabase* ,
    int
);




extern int XrmEnumerateDatabase(
    XrmDatabase ,
    XrmNameList ,
    XrmClassList ,
    int ,
    int (*)(
      XrmDatabase* ,
      XrmBindingList ,
      XrmQuarkList ,
      XrmRepresentation* ,
      XrmValue* ,
      XPointer
      ) ,
    XPointer
);

extern const char *XrmLocaleOfDatabase(
    XrmDatabase
);
typedef enum {
    XrmoptionNoArg,
    XrmoptionIsArg,
    XrmoptionStickyArg,
    XrmoptionSepArg,
    XrmoptionResArg,
    XrmoptionSkipArg,
    XrmoptionSkipLine,
    XrmoptionSkipNArgs

} XrmOptionKind;

typedef struct {
    char *option;
    char *specifier;
    XrmOptionKind argKind;
    XPointer value;
} XrmOptionDescRec, *XrmOptionDescList;


extern void XrmParseCommand(
    XrmDatabase* ,
    XrmOptionDescList ,
    int ,
    const char* ,
    int* ,
    char**
);





















extern void *memcpy (void *__restrict __dest, const void *__restrict __src,
       size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));


extern void *memmove (void *__dest, const void *__src, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));






extern void *memccpy (void *__restrict __dest, const void *__restrict __src,
        int __c, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));





extern void *memset (void *__s, int __c, size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));


extern int memcmp (const void *__s1, const void *__s2, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern void *memchr (const void *__s, int __c, size_t __n)
      __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));




extern char *strcpy (char *__restrict __dest, const char *__restrict __src)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));

extern char *strncpy (char *__restrict __dest,
        const char *__restrict __src, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));


extern char *strcat (char *__restrict __dest, const char *__restrict __src)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));

extern char *strncat (char *__restrict __dest, const char *__restrict __src,
        size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));


extern int strcmp (const char *__s1, const char *__s2)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));

extern int strncmp (const char *__s1, const char *__s2, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));


extern int strcoll (const char *__s1, const char *__s2)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));

extern size_t strxfrm (char *__restrict __dest,
         const char *__restrict __src, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));






typedef struct __locale_struct
{

  struct __locale_data *__locales[13];


  const unsigned short int *__ctype_b;
  const int *__ctype_tolower;
  const int *__ctype_toupper;


  const char *__names[13];
} *__locale_t;


typedef __locale_t locale_t;


extern int strcoll_l (const char *__s1, const char *__s2, __locale_t __l)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2, 3)));

extern size_t strxfrm_l (char *__dest, const char *__src, size_t __n,
    __locale_t __l) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2, 4)));





extern char *strdup (const char *__s)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) __attribute__ ((__nonnull__ (1)));






extern char *strndup (const char *__string, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) __attribute__ ((__nonnull__ (1)));

extern char *strchr (const char *__s, int __c)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern char *strrchr (const char *__s, int __c)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));





extern size_t strcspn (const char *__s, const char *__reject)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));


extern size_t strspn (const char *__s, const char *__accept)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strpbrk (const char *__s, const char *__accept)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strstr (const char *__haystack, const char *__needle)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));




extern char *strtok (char *__restrict __s, const char *__restrict __delim)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));




extern char *__strtok_r (char *__restrict __s,
    const char *__restrict __delim,
    char **__restrict __save_ptr)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2, 3)));

extern char *strtok_r (char *__restrict __s, const char *__restrict __delim,
         char **__restrict __save_ptr)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2, 3)));


extern size_t strlen (const char *__s)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));





extern size_t strnlen (const char *__string, size_t __maxlen)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));





extern char *strerror (int __errnum) __attribute__ ((__nothrow__ , __leaf__));

extern int strerror_r (int __errnum, char *__buf, size_t __buflen) __asm__ ("" "__xpg_strerror_r") __attribute__ ((__nothrow__ , __leaf__))

                        __attribute__ ((__nonnull__ (2)));
extern char *strerror_l (int __errnum, __locale_t __l) __attribute__ ((__nothrow__ , __leaf__));





extern void __bzero (void *__s, size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));



extern void bcopy (const void *__src, void *__dest, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));


extern void bzero (void *__s, size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));


extern int bcmp (const void *__s1, const void *__s2, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *index (const char *__s, int __c)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern char *rindex (const char *__s, int __c)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));




extern int ffs (int __i) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern int strcasecmp (const char *__s1, const char *__s2)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));


extern int strncasecmp (const char *__s1, const char *__s2, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strsep (char **__restrict __stringp,
       const char *__restrict __delim)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));




extern char *strsignal (int __sig) __attribute__ ((__nothrow__ , __leaf__));


extern char *__stpcpy (char *__restrict __dest, const char *__restrict __src)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *stpcpy (char *__restrict __dest, const char *__restrict __src)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));



extern char *__stpncpy (char *__restrict __dest,
   const char *__restrict __src, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *stpncpy (char *__restrict __dest,
        const char *__restrict __src, size_t __n)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));





typedef XtPointer Opaque;






typedef struct _ObjectRec *Object;
typedef struct _ObjectClassRec *ObjectClass;


extern WidgetClass objectClass;





typedef struct _RectObjRec *RectObj;
typedef struct _RectObjClassRec *RectObjClass;


extern WidgetClass rectObjClass;




typedef struct _TranslationData *XtTranslations;
typedef struct _TranslationData *XtAccelerators;
typedef unsigned int Modifiers;

typedef void (*XtActionProc)(
    Widget ,
    XEvent* ,
    String* ,
    Cardinal*
);

typedef XtActionProc* XtBoundActions;

typedef struct _XtActionsRec{
    String string;
    XtActionProc proc;
} XtActionsRec;

typedef enum {


    XtAddress,
    XtBaseOffset,
    XtImmediate,
    XtResourceString,
    XtResourceQuark,
    XtWidgetBaseOffset,
    XtProcedureArg
} XtAddressMode;

typedef struct {
    XtAddressMode address_mode;
    XtPointer address_id;
    Cardinal size;
} XtConvertArgRec, *XtConvertArgList;

typedef void (*XtConvertArgProc)(
    Widget ,
    Cardinal* ,
    XrmValue*
);

typedef struct {
    XtGeometryMask request_mode;
    Position x, y;
    Dimension width, height, border_width;
    Widget sibling;
    int stack_mode;
} XtWidgetGeometry;







typedef void (*XtConverter)(
    XrmValue* ,
    Cardinal* ,
    XrmValue* ,
    XrmValue*
);

typedef Boolean (*XtTypeConverter)(
    Display* ,
    XrmValue* ,
    Cardinal* ,
    XrmValue* ,
    XrmValue* ,
    XtPointer*
);

typedef void (*XtDestructor)(
    XtAppContext ,
    XrmValue* ,
    XtPointer ,
    XrmValue* ,
    Cardinal*
);

typedef Opaque XtCacheRef;

typedef Opaque XtActionHookId;

typedef void (*XtActionHookProc)(
    Widget ,
    XtPointer ,
    String ,
    XEvent* ,
    String* ,
    Cardinal*
);

typedef unsigned long XtBlockHookId;

typedef void (*XtBlockHookProc)(
    XtPointer
);

typedef void (*XtKeyProc)(
    Display* ,
    KeyCode ,
    Modifiers ,
    Modifiers* ,
    KeySym*
);

typedef void (*XtCaseProc)(
    Display* ,
    KeySym ,
    KeySym* ,
    KeySym*
);

typedef void (*XtEventHandler)(
    Widget ,
    XtPointer ,
    XEvent* ,
    Boolean*
);
typedef unsigned long EventMask;

typedef enum {XtListHead, XtListTail } XtListPosition;

typedef unsigned long XtInputMask;





typedef void (*XtTimerCallbackProc)(
    XtPointer ,
    XtIntervalId*
);

typedef void (*XtInputCallbackProc)(
    XtPointer ,
    int* ,
    XtInputId*
);

typedef void (*XtSignalCallbackProc)(
    XtPointer ,
    XtSignalId*
);

typedef struct {
    String name;
    XtArgVal value;
} Arg, *ArgList;

typedef XtPointer XtVarArgsList;

typedef void (*XtCallbackProc)(
    Widget ,
    XtPointer ,
    XtPointer
);

typedef struct _XtCallbackRec {
    XtCallbackProc callback;
    XtPointer closure;
} XtCallbackRec, *XtCallbackList;

typedef enum {
 XtCallbackNoList,
 XtCallbackHasNone,
 XtCallbackHasSome
} XtCallbackStatus;

typedef enum {
    XtGeometryYes,
    XtGeometryNo,
    XtGeometryAlmost,
    XtGeometryDone
} XtGeometryResult;

typedef enum {XtGrabNone, XtGrabNonexclusive, XtGrabExclusive} XtGrabKind;

typedef struct {
    Widget shell_widget;
    Widget enable_widget;
} XtPopdownIDRec, *XtPopdownID;

typedef struct _XtResource {
    String resource_name;
    String resource_class;
    String resource_type;
    Cardinal resource_size;
    Cardinal resource_offset;
    String default_type;
    XtPointer default_addr;
} XtResource, *XtResourceList;

typedef void (*XtResourceDefaultProc)(
    Widget ,
    int ,
    XrmValue*
);

typedef String (*XtLanguageProc)(
    Display* ,
    String ,
    XtPointer
);

typedef void (*XtErrorMsgHandler)(
    String ,
    String ,
    String ,
    String ,
    String* ,
    Cardinal*
);

typedef void (*XtErrorHandler)(
  String
);

typedef void (*XtCreatePopupChildProc)(
    Widget
);

typedef Boolean (*XtWorkProc)(
    XtPointer
);

typedef struct {
    char match;
    String substitution;
} SubstitutionRec, *Substitution;

typedef Boolean (*XtFilePredicate)(
   String
);

typedef XtPointer XtRequestId;

typedef Boolean (*XtConvertSelectionProc)(
    Widget ,
    Atom* ,
    Atom* ,
    Atom* ,
    XtPointer* ,
    unsigned long* ,
    int*
);

typedef void (*XtLoseSelectionProc)(
    Widget ,
    Atom*
);

typedef void (*XtSelectionDoneProc)(
    Widget ,
    Atom* ,
    Atom*
);

typedef void (*XtSelectionCallbackProc)(
    Widget ,
    XtPointer ,
    Atom* ,
    Atom* ,
    XtPointer ,
    unsigned long* ,
    int*
);

typedef void (*XtLoseSelectionIncrProc)(
    Widget ,
    Atom* ,
    XtPointer
);

typedef void (*XtSelectionDoneIncrProc)(
    Widget ,
    Atom* ,
    Atom* ,
    XtRequestId* ,
    XtPointer
);

typedef Boolean (*XtConvertSelectionIncrProc)(
    Widget ,
    Atom* ,
    Atom* ,
    Atom* ,
    XtPointer* ,
    unsigned long* ,
    int* ,
    unsigned long* ,
    XtPointer ,
    XtRequestId*
);

typedef void (*XtCancelConvertSelectionProc)(
    Widget ,
    Atom* ,
    Atom* ,
    XtRequestId* ,
    XtPointer
);

typedef Boolean (*XtEventDispatchProc)(
    XEvent*
);

typedef void (*XtExtensionSelectProc)(
    Widget ,
    int* ,
    XtPointer* ,
    int ,
    XtPointer
);









extern Boolean XtConvertAndStore(
    Widget ,
    const char* ,
    XrmValue* ,
    const char* ,
    XrmValue*
);

extern Boolean XtCallConverter(
    Display* ,
    XtTypeConverter ,
    XrmValuePtr ,
    Cardinal ,
    XrmValuePtr ,
    XrmValue* ,
    XtCacheRef*
);

extern Boolean XtDispatchEvent(
    XEvent*
);

extern Boolean XtCallAcceptFocus(
    Widget ,
    Time*
);

extern Boolean XtPeekEvent(
    XEvent*
);

extern Boolean XtAppPeekEvent(
    XtAppContext ,
    XEvent*
);

extern Boolean XtIsSubclass(
    Widget ,
    WidgetClass
);

extern Boolean XtIsObject(
    Widget
);

extern Boolean _XtCheckSubclassFlag(
    Widget ,
    XtEnum
);

extern Boolean _XtIsSubclassOf(
    Widget ,
    WidgetClass ,
    WidgetClass ,
    XtEnum
);

extern Boolean XtIsManaged(
    Widget
);

extern Boolean XtIsRealized(
    Widget
);

extern Boolean XtIsSensitive(
    Widget
);

extern Boolean XtOwnSelection(
    Widget ,
    Atom ,
    Time ,
    XtConvertSelectionProc ,
    XtLoseSelectionProc ,
    XtSelectionDoneProc
);

extern Boolean XtOwnSelectionIncremental(
    Widget ,
    Atom ,
    Time ,
    XtConvertSelectionIncrProc ,
    XtLoseSelectionIncrProc ,
    XtSelectionDoneIncrProc ,
    XtCancelConvertSelectionProc ,
    XtPointer
);

extern XtGeometryResult XtMakeResizeRequest(
    Widget ,
    Dimension ,
    Dimension ,
    Dimension* ,
    Dimension*
);

extern void XtTranslateCoords(
    Widget ,
    Position ,
    Position ,
    Position* ,
    Position*
);

extern KeySym* XtGetKeysymTable(
    Display* ,
    KeyCode* ,
    int*
);

extern void XtKeysymToKeycodeList(
    Display* ,
    KeySym ,
    KeyCode** ,
    Cardinal*
);

extern void XtStringConversionWarning(
    const char* ,
    const char*
);

extern void XtDisplayStringConversionWarning(
    Display* ,
    const char* ,
    const char*
);

extern XtConvertArgRec const colorConvertArgs[];
extern XtConvertArgRec const screenConvertArg[];

extern void XtAppAddConverter(
    XtAppContext ,
    const char* ,
    const char* ,
    XtConverter ,
    XtConvertArgList ,
    Cardinal
);

extern void XtAddConverter(
    const char* ,
    const char* ,
    XtConverter ,
    XtConvertArgList ,
    Cardinal
);

extern void XtSetTypeConverter(
    const char* ,
    const char* ,
    XtTypeConverter ,
    XtConvertArgList ,
    Cardinal ,
    XtCacheType ,
    XtDestructor
);

extern void XtAppSetTypeConverter(
    XtAppContext ,
    const char* ,
    const char* ,
    XtTypeConverter ,
    XtConvertArgList ,
    Cardinal ,
    XtCacheType ,
    XtDestructor
);

extern void XtConvert(
    Widget ,
    const char* ,
    XrmValue* ,
    const char* ,
    XrmValue*
);

extern void XtDirectConvert(
    XtConverter ,
    XrmValuePtr ,
    Cardinal ,
    XrmValuePtr ,
    XrmValue*
);







extern XtTranslations XtParseTranslationTable(
    const char*
);

extern XtAccelerators XtParseAcceleratorTable(
    const char*
);

extern void XtOverrideTranslations(
    Widget ,
    XtTranslations
);

extern void XtAugmentTranslations(
    Widget ,
    XtTranslations
);

extern void XtInstallAccelerators(
    Widget ,
    Widget
);

extern void XtInstallAllAccelerators(
    Widget ,
    Widget
);

extern void XtUninstallTranslations(
    Widget
);

extern void XtAppAddActions(
    XtAppContext ,
    XtActionList ,
    Cardinal
);

extern void XtAddActions(
    XtActionList ,
    Cardinal
);

extern XtActionHookId XtAppAddActionHook(
    XtAppContext ,
    XtActionHookProc ,
    XtPointer
);

extern void XtRemoveActionHook(
    XtActionHookId
);

extern void XtGetActionList(
    WidgetClass ,
    XtActionList* ,
    Cardinal*
);

extern void XtCallActionProc(
    Widget ,
    const char* ,
    XEvent* ,
    String* ,
    Cardinal
);

extern void XtRegisterGrabAction(
    XtActionProc ,
    Boolean ,
    unsigned int ,
    int ,
    int
);

extern void XtSetMultiClickTime(
    Display* ,
    int
);

extern int XtGetMultiClickTime(
    Display*
);

extern KeySym XtGetActionKeysym(
    XEvent* ,
    Modifiers*
);







extern void XtTranslateKeycode(
    Display* ,
    KeyCode ,
    Modifiers ,
    Modifiers* ,
    KeySym*
);

extern void XtTranslateKey(
    Display* ,
    KeyCode ,
    Modifiers ,
    Modifiers* ,
    KeySym*
);

extern void XtSetKeyTranslator(
    Display* ,
    XtKeyProc
);

extern void XtRegisterCaseConverter(
    Display* ,
    XtCaseProc ,
    KeySym ,
    KeySym
);

extern void XtConvertCase(
    Display* ,
    KeySym ,
    KeySym* ,
    KeySym*
);
extern void XtAddEventHandler(
    Widget ,
    EventMask ,
    Boolean ,
    XtEventHandler ,
    XtPointer
);

extern void XtRemoveEventHandler(
    Widget ,
    EventMask ,
    Boolean ,
    XtEventHandler ,
    XtPointer
);

extern void XtAddRawEventHandler(
    Widget ,
    EventMask ,
    Boolean ,
    XtEventHandler ,
    XtPointer
);

extern void XtRemoveRawEventHandler(
    Widget ,
    EventMask ,
    Boolean ,
    XtEventHandler ,
    XtPointer
);

extern void XtInsertEventHandler(
    Widget ,
    EventMask ,
    Boolean ,
    XtEventHandler ,
    XtPointer ,
    XtListPosition
);

extern void XtInsertRawEventHandler(
    Widget ,
    EventMask ,
    Boolean ,
    XtEventHandler ,
    XtPointer ,
    XtListPosition
);

extern XtEventDispatchProc XtSetEventDispatcher(
    Display* ,
    int ,
    XtEventDispatchProc
);

extern Boolean XtDispatchEventToWidget(
    Widget ,
    XEvent*
);

extern void XtInsertEventTypeHandler(
    Widget ,
    int ,
    XtPointer ,
    XtEventHandler ,
    XtPointer ,
    XtListPosition
);

extern void XtRemoveEventTypeHandler(
    Widget ,
    int ,
    XtPointer ,
    XtEventHandler ,
    XtPointer
);

extern EventMask XtBuildEventMask(
    Widget
);

extern void XtRegisterExtensionSelector(
    Display* ,
    int ,
    int ,
    XtExtensionSelectProc ,
    XtPointer
);

extern void XtAddGrab(
    Widget ,
    Boolean ,
    Boolean
);

extern void XtRemoveGrab(
    Widget
);

extern void XtProcessEvent(
    XtInputMask
);

extern void XtAppProcessEvent(
    XtAppContext ,
    XtInputMask
);

extern void XtMainLoop(
    void
);

extern void XtAppMainLoop(
    XtAppContext
);

extern void XtAddExposureToRegion(
    XEvent* ,
    Region
);

extern void XtSetKeyboardFocus(
    Widget ,
    Widget
);

extern Widget XtGetKeyboardFocusWidget(
    Widget
);

extern XEvent* XtLastEventProcessed(
    Display*
);

extern Time XtLastTimestampProcessed(
    Display*
);







extern XtIntervalId XtAddTimeOut(
    unsigned long ,
    XtTimerCallbackProc ,
    XtPointer
);

extern XtIntervalId XtAppAddTimeOut(
    XtAppContext ,
    unsigned long ,
    XtTimerCallbackProc ,
    XtPointer
);

extern void XtRemoveTimeOut(
    XtIntervalId
);

extern XtInputId XtAddInput(
    int ,
    XtPointer ,
    XtInputCallbackProc ,
    XtPointer
);

extern XtInputId XtAppAddInput(
    XtAppContext ,
    int ,
    XtPointer ,
    XtInputCallbackProc ,
    XtPointer
);

extern void XtRemoveInput(
    XtInputId
);

extern XtSignalId XtAddSignal(
    XtSignalCallbackProc ,
    XtPointer );

extern XtSignalId XtAppAddSignal(
    XtAppContext ,
    XtSignalCallbackProc ,
    XtPointer
);

extern void XtRemoveSignal(
    XtSignalId
);

extern void XtNoticeSignal(
    XtSignalId
);

extern void XtNextEvent(
    XEvent*
);

extern void XtAppNextEvent(
    XtAppContext ,
    XEvent*
);







extern Boolean XtPending(
    void
);

extern XtInputMask XtAppPending(
    XtAppContext
);

extern XtBlockHookId XtAppAddBlockHook(
    XtAppContext ,
    XtBlockHookProc ,
    XtPointer
);

extern void XtRemoveBlockHook(
    XtBlockHookId
);
extern Boolean XtIsOverrideShell(Widget );







extern Boolean XtIsVendorShell(Widget );





extern Boolean XtIsTransientShell(Widget );






extern Boolean XtIsApplicationShell(Widget );





extern Boolean XtIsSessionShell(Widget );




extern void XtRealizeWidget(
    Widget
);

void XtUnrealizeWidget(
    Widget
);

extern void XtDestroyWidget(
    Widget
);

extern void XtSetSensitive(
    Widget ,
    Boolean
);

extern void XtSetMappedWhenManaged(
    Widget ,
    Boolean
);

extern Widget XtNameToWidget(
    Widget ,
    const char*
);

extern Widget XtWindowToWidget(
    Display* ,
    Window
);

extern XtPointer XtGetClassExtension(
    WidgetClass ,
    Cardinal ,
    XrmQuark ,
    long ,
    Cardinal
);
extern ArgList XtMergeArgLists(
    ArgList ,
    Cardinal ,
    ArgList ,
    Cardinal
);
extern XtVarArgsList XtVaCreateArgsList(
    XtPointer , ...
) __attribute__ ((__sentinel__(0)));
extern Display *XtDisplay(
    Widget
);

extern Display *XtDisplayOfObject(
    Widget
);

extern Screen *XtScreen(
    Widget
);

extern Screen *XtScreenOfObject(
    Widget
);

extern Window XtWindow(
    Widget
);

extern Window XtWindowOfObject(
    Widget
);

extern String XtName(
    Widget
);

extern WidgetClass XtSuperclass(
    Widget
);

extern WidgetClass XtClass(
    Widget
);

extern Widget XtParent(
    Widget
);




extern void XtMapWidget(Widget );



extern void XtUnmapWidget(Widget );



extern void XtAddCallback(
    Widget ,
    const char* ,
    XtCallbackProc ,
    XtPointer
);

extern void XtRemoveCallback(
    Widget ,
    const char* ,
    XtCallbackProc ,
    XtPointer
);

extern void XtAddCallbacks(
    Widget ,
    const char* ,
    XtCallbackList
);

extern void XtRemoveCallbacks(
    Widget ,
    const char* ,
    XtCallbackList
);

extern void XtRemoveAllCallbacks(
    Widget ,
    const char*
);


extern void XtCallCallbacks(
    Widget ,
    const char* ,
    XtPointer
);

extern void XtCallCallbackList(
    Widget ,
    XtCallbackList ,
    XtPointer
);

extern XtCallbackStatus XtHasCallbacks(
    Widget ,
    const char*
);
extern XtGeometryResult XtMakeGeometryRequest(
    Widget ,
    XtWidgetGeometry* ,
    XtWidgetGeometry*
);

extern XtGeometryResult XtQueryGeometry(
    Widget ,
    XtWidgetGeometry* ,
    XtWidgetGeometry*
);

extern Widget XtCreatePopupShell(
    const char* ,
    WidgetClass ,
    Widget ,
    ArgList ,
    Cardinal
);

extern Widget XtVaCreatePopupShell(
    const char* ,
    WidgetClass ,
    Widget ,
    ...
) __attribute__ ((__sentinel__(0)));

extern void XtPopup(
    Widget ,
    XtGrabKind
);

extern void XtPopupSpringLoaded(
    Widget
);

extern void XtCallbackNone(
    Widget ,
    XtPointer ,
    XtPointer
);

extern void XtCallbackNonexclusive(
    Widget ,
    XtPointer ,
    XtPointer
);

extern void XtCallbackExclusive(
    Widget ,
    XtPointer ,
    XtPointer
);

extern void XtPopdown(
    Widget
);

extern void XtCallbackPopdown(
    Widget ,
    XtPointer ,
    XtPointer
);

extern void XtMenuPopupAction(
    Widget ,
    XEvent* ,
    String* ,
    Cardinal*
);

extern Widget XtCreateWidget(
    const char* ,
    WidgetClass ,
    Widget ,
    ArgList ,
    Cardinal
);

extern Widget XtCreateManagedWidget(
    const char* ,
    WidgetClass ,
    Widget ,
    ArgList ,
    Cardinal
);

extern Widget XtVaCreateWidget(
    const char* ,
    WidgetClass ,
    Widget ,
    ...
) __attribute__ ((__sentinel__(0)));

extern Widget XtVaCreateManagedWidget(
    const char* ,
    WidgetClass ,
    Widget ,
    ...
) __attribute__ ((__sentinel__(0)));

extern Widget XtCreateApplicationShell(
    const char* ,
    WidgetClass ,
    ArgList ,
    Cardinal
);

extern Widget XtAppCreateShell(
    const char* ,
    const char* ,
    WidgetClass ,
    Display* ,
    ArgList ,
    Cardinal
);

extern Widget XtVaAppCreateShell(
    const char* ,
    const char* ,
    WidgetClass ,
    Display* ,
    ...
) __attribute__ ((__sentinel__(0)));







extern void XtToolkitInitialize(
    void
);

extern XtLanguageProc XtSetLanguageProc(
    XtAppContext ,
    XtLanguageProc ,
    XtPointer
);

extern void XtDisplayInitialize(
    XtAppContext ,
    Display* ,
    const char* ,
    const char* ,
    XrmOptionDescRec* ,
    Cardinal ,
    int* ,
    char**
);

extern Widget XtOpenApplication(
    XtAppContext* ,
    const char* ,
    XrmOptionDescList ,
    Cardinal ,
    int* ,
    String* ,
    String* ,
    WidgetClass ,
    ArgList ,
    Cardinal
);

extern Widget XtVaOpenApplication(
    XtAppContext* ,
    const char* ,
    XrmOptionDescList ,
    Cardinal ,
    int* ,
    String* ,
    String* ,
    WidgetClass ,
    ...
) __attribute__ ((__sentinel__(0)));

extern Widget XtAppInitialize(
    XtAppContext* ,
    const char* ,
    XrmOptionDescList ,
    Cardinal ,
    int* ,
    String* ,
    String* ,
    ArgList ,
    Cardinal
);

extern Widget XtVaAppInitialize(
    XtAppContext* ,
    const char* ,
    XrmOptionDescList ,
    Cardinal ,
    int* ,
    String* ,
    String* ,
    ...
) __attribute__ ((__sentinel__(0)));

extern Widget XtInitialize(
    const char* ,
    const char* ,
    XrmOptionDescRec* ,
    Cardinal ,
    int* ,
    char**
);

extern Display *XtOpenDisplay(
    XtAppContext ,
    const char* ,
    const char* ,
    const char* ,
    XrmOptionDescRec* ,
    Cardinal ,
    int* ,
    char**
);

extern XtAppContext XtCreateApplicationContext(
    void
);

extern void XtAppSetFallbackResources(
    XtAppContext ,
    String*
);

extern void XtDestroyApplicationContext(
    XtAppContext
);

extern void XtInitializeWidgetClass(
    WidgetClass
);

extern XtAppContext XtWidgetToApplicationContext(
    Widget
);

extern XtAppContext XtDisplayToApplicationContext(
    Display*
);

extern XrmDatabase XtDatabase(
    Display*
);

extern XrmDatabase XtScreenDatabase(
    Screen*
);

extern void XtCloseDisplay(
    Display*
);

extern void XtGetApplicationResources(
    Widget ,
    XtPointer ,
    XtResourceList ,
    Cardinal ,
    ArgList ,
    Cardinal
);

extern void XtVaGetApplicationResources(
    Widget ,
    XtPointer ,
    XtResourceList ,
    Cardinal ,
    ...
) __attribute__ ((__sentinel__(0)));

extern void XtGetSubresources(
    Widget ,
    XtPointer ,
    const char* ,
    const char* ,
    XtResourceList ,
    Cardinal ,
    ArgList ,
    Cardinal
);

extern void XtVaGetSubresources(
    Widget ,
    XtPointer ,
    const char* ,
    const char* ,
    XtResourceList ,
    Cardinal ,
    ...
) __attribute__ ((__sentinel__(0)));

extern void XtSetValues(
    Widget ,
    ArgList ,
    Cardinal
);

extern void XtVaSetValues(
    Widget ,
    ...
) __attribute__ ((__sentinel__(0)));

extern void XtGetValues(
    Widget ,
    ArgList ,
    Cardinal
);

extern void XtVaGetValues(
    Widget ,
    ...
) __attribute__ ((__sentinel__(0)));

extern void XtSetSubvalues(
    XtPointer ,
    XtResourceList ,
    Cardinal ,
    ArgList ,
    Cardinal
);

extern void XtVaSetSubvalues(
    XtPointer ,
    XtResourceList ,
    Cardinal ,
    ...
) __attribute__ ((__sentinel__(0)));

extern void XtGetSubvalues(
    XtPointer ,
    XtResourceList ,
    Cardinal ,
    ArgList ,
    Cardinal
);

extern void XtVaGetSubvalues(
    XtPointer ,
    XtResourceList ,
    Cardinal ,
    ...
) __attribute__ ((__sentinel__(0)));

extern void XtGetResourceList(
    WidgetClass ,
    XtResourceList* ,
    Cardinal*
);

extern void XtGetConstraintResourceList(
    WidgetClass ,
    XtResourceList* ,
    Cardinal*
);
typedef struct _XtCheckpointTokenRec {
    int save_type;
    int interact_style;
    Boolean shutdown;
    Boolean fast;
    Boolean cancel_shutdown;
    int phase;
    int interact_dialog_type;
    Boolean request_cancel;
    Boolean request_next_phase;
    Boolean save_success;
    int type;
    Widget widget;
} XtCheckpointTokenRec, *XtCheckpointToken;

XtCheckpointToken XtSessionGetToken(
    Widget
);

void XtSessionReturnToken(
    XtCheckpointToken
);







extern XtErrorMsgHandler XtAppSetErrorMsgHandler(
    XtAppContext ,
    XtErrorMsgHandler
);

extern void XtSetErrorMsgHandler(
    XtErrorMsgHandler
);

extern XtErrorMsgHandler XtAppSetWarningMsgHandler(
    XtAppContext ,
    XtErrorMsgHandler
);

extern void XtSetWarningMsgHandler(
    XtErrorMsgHandler
);

extern void XtAppErrorMsg(
    XtAppContext ,
    const char* ,
    const char* ,
    const char* ,
    const char* ,
    String* ,
    Cardinal*
);

extern void XtErrorMsg(
    const char* ,
    const char* ,
    const char* ,
    const char* ,
    String* ,
    Cardinal*
);

extern void XtAppWarningMsg(
    XtAppContext ,
    const char* ,
    const char* ,
    const char* ,
    const char* ,
    String* ,
    Cardinal*
);

extern void XtWarningMsg(
    const char* ,
    const char* ,
    const char* ,
    const char* ,
    String* ,
    Cardinal*
);

extern XtErrorHandler XtAppSetErrorHandler(
    XtAppContext ,
    XtErrorHandler
);

extern void XtSetErrorHandler(
    XtErrorHandler
);

extern XtErrorHandler XtAppSetWarningHandler(
    XtAppContext ,
    XtErrorHandler
);

extern void XtSetWarningHandler(
    XtErrorHandler
);

extern void XtAppError(
    XtAppContext ,
    const char*
);

extern void XtError(
    const char*
);

extern void XtAppWarning(
    XtAppContext ,
    const char*
);

extern void XtWarning(
    const char*
);

extern XrmDatabase *XtAppGetErrorDatabase(
    XtAppContext
);

extern XrmDatabase *XtGetErrorDatabase(
    void
);

extern void XtAppGetErrorDatabaseText(
    XtAppContext ,
    const char* ,
    const char* ,
    const char* ,
    const char* ,
    String ,
    int ,
    XrmDatabase
);

extern void XtGetErrorDatabaseText(
    const char* ,
    const char* ,
    const char* ,
    const char* ,
    String ,
    int
);







extern char *XtMalloc(
    Cardinal
);

extern char *XtCalloc(
    Cardinal ,
    Cardinal
);

extern char *XtRealloc(
    char* ,
    Cardinal
);

extern void XtFree(
    char*
);




extern Cardinal XtAsprintf(
    String *new_string,
    const char * __restrict__ format,
    ...
) __attribute__((__format__(__printf__,2,3)));
extern String XtNewString(String );
extern XtWorkProcId XtAddWorkProc(
    XtWorkProc ,
    XtPointer
);

extern XtWorkProcId XtAppAddWorkProc(
    XtAppContext ,
    XtWorkProc ,
    XtPointer
);

extern void XtRemoveWorkProc(
    XtWorkProcId
);







extern GC XtGetGC(
    Widget ,
    XtGCMask ,
    XGCValues*
);

extern GC XtAllocateGC(
    Widget ,
    Cardinal ,
    XtGCMask ,
    XGCValues* ,
    XtGCMask ,
    XtGCMask
);





extern void XtDestroyGC(
    GC
);

extern void XtReleaseGC(
    Widget ,
    GC
);



extern void XtAppReleaseCacheRefs(
    XtAppContext ,
    XtCacheRef*
);

extern void XtCallbackReleaseCacheRef(
    Widget ,
    XtPointer ,
    XtPointer
);

extern void XtCallbackReleaseCacheRefList(
    Widget ,
    XtPointer ,
    XtPointer
);

extern void XtSetWMColormapWindows(
    Widget ,
    Widget* ,
    Cardinal
);

extern String XtFindFile(
    const char* ,
    Substitution ,
    Cardinal ,
    XtFilePredicate
);

extern String XtResolvePathname(
    Display* ,
    const char* ,
    const char* ,
    const char* ,
    const char* ,
    Substitution ,
    Cardinal ,
    XtFilePredicate
);
extern void XtDisownSelection(
    Widget ,
    Atom ,
    Time
);

extern void XtGetSelectionValue(
    Widget ,
    Atom ,
    Atom ,
    XtSelectionCallbackProc ,
    XtPointer ,
    Time
);

extern void XtGetSelectionValues(
    Widget ,
    Atom ,
    Atom* ,
    int ,
    XtSelectionCallbackProc ,
    XtPointer* ,
    Time
);

extern void XtAppSetSelectionTimeout(
    XtAppContext ,
    unsigned long
);

extern void XtSetSelectionTimeout(
    unsigned long
);

extern unsigned long XtAppGetSelectionTimeout(
    XtAppContext
);

extern unsigned long XtGetSelectionTimeout(
    void
);

extern XSelectionRequestEvent *XtGetSelectionRequest(
    Widget ,
    Atom ,
    XtRequestId
);

extern void XtGetSelectionValueIncremental(
    Widget ,
    Atom ,
    Atom ,
    XtSelectionCallbackProc ,
    XtPointer ,
    Time
);

extern void XtGetSelectionValuesIncremental(
    Widget ,
    Atom ,
    Atom* ,
    int ,
    XtSelectionCallbackProc ,
    XtPointer* ,
    Time
);

extern void XtSetSelectionParameters(
    Widget ,
    Atom ,
    Atom ,
    XtPointer ,
    unsigned long ,
    int
);

extern void XtGetSelectionParameters(
    Widget ,
    Atom ,
    XtRequestId ,
    Atom* ,
    XtPointer* ,
    unsigned long* ,
    int*
);

extern void XtCreateSelectionRequest(
    Widget ,
    Atom
);

extern void XtSendSelectionRequest(
    Widget ,
    Atom ,
    Time
);

extern void XtCancelSelectionRequest(
    Widget ,
    Atom
);

extern Atom XtReservePropertyAtom(
    Widget
);

extern void XtReleasePropertyAtom(
    Widget ,
    Atom
);

extern void XtGrabKey(
    Widget ,
    KeyCode ,
    Modifiers ,
    Boolean ,
    int ,
    int
);

extern void XtUngrabKey(
    Widget ,
    KeyCode ,
    Modifiers
);

extern int XtGrabKeyboard(
    Widget ,
    Boolean ,
    int ,
    int ,
    Time
);

extern void XtUngrabKeyboard(
    Widget ,
    Time
);

extern void XtGrabButton(
    Widget ,
    int ,
    Modifiers ,
    Boolean ,
    unsigned int ,
    int ,
    int ,
    Window ,
    Cursor
);

extern void XtUngrabButton(
    Widget ,
    unsigned int ,
    Modifiers
);

extern int XtGrabPointer(
    Widget ,
    Boolean ,
    unsigned int ,
    int ,
    int ,
    Window ,
    Cursor ,
    Time
);

extern void XtUngrabPointer(
    Widget ,
    Time
);

extern void XtGetApplicationNameAndClass(
    Display* ,
    String* ,
    String*
);

extern void XtRegisterDrawable(
    Display* ,
    Drawable ,
    Widget
);

extern void XtUnregisterDrawable(
    Display* ,
    Drawable
);

extern Widget XtHooksOfDisplay(
    Display*
);

typedef struct {
    String type;
    Widget widget;
    ArgList args;
    Cardinal num_args;
} XtCreateHookDataRec, *XtCreateHookData;

typedef struct {
    String type;
    Widget widget;
    XtPointer event_data;
    Cardinal num_event_data;
} XtChangeHookDataRec, *XtChangeHookData;

typedef struct {
    Widget old, req;
    ArgList args;
    Cardinal num_args;
} XtChangeHookSetValuesDataRec, *XtChangeHookSetValuesData;

typedef struct {
    String type;
    Widget widget;
    XtGeometryMask changeMask;
    XWindowChanges changes;
} XtConfigureHookDataRec, *XtConfigureHookData;

typedef struct {
    String type;
    Widget widget;
    XtWidgetGeometry* request;
    XtWidgetGeometry* reply;
    XtGeometryResult result;
} XtGeometryHookDataRec, *XtGeometryHookData;

typedef struct {
    String type;
    Widget widget;
} XtDestroyHookDataRec, *XtDestroyHookData;

extern void XtGetDisplays(
    XtAppContext ,
    Display*** ,
    Cardinal*
);

extern Boolean XtToolkitThreadInitialize(
    void
);

extern void XtAppSetExitFlag(
    XtAppContext
);

extern Boolean XtAppGetExitFlag(
    XtAppContext
);

extern void XtAppLock(
    XtAppContext
);

extern void XtAppUnlock(
    XtAppContext
);
extern Boolean XtCvtStringToAcceleratorTable(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToAtom(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToBool(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToBoolean(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToCommandArgArray(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToCursor(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToDimension(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToDirectoryString(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToDisplay(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToFile(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToFloat(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToFont(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToFontSet(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToFontStruct(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToGravity(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToInitialState(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToInt(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToPixel(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);



extern Boolean XtCvtStringToRestartStyle(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToShort(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToTranslationTable(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToUnsignedChar(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtStringToVisual(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);



extern Boolean XtCvtIntToBool(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtIntToBoolean(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtIntToColor(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);



extern Boolean XtCvtIntToFloat(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtIntToFont(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtIntToPixel(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtIntToPixmap(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);



extern Boolean XtCvtIntToShort(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);

extern Boolean XtCvtIntToUnsignedChar(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);



extern Boolean XtCvtColorToPixel(
    Display* ,
    XrmValuePtr ,
    Cardinal* ,
    XrmValuePtr ,
    XrmValuePtr ,
    XtPointer*
);













typedef struct {
    long xrm_name;
    long xrm_class;
    long xrm_type;
    Cardinal xrm_size;
    int xrm_offset;
    long xrm_default_type;
    XtPointer xrm_default_addr;
} XrmResource, *XrmResourceList;

typedef unsigned long XtVersionType;
typedef void (*XtProc)(
    void
);

typedef void (*XtWidgetClassProc)(
    WidgetClass
);

typedef void (*XtWidgetProc)(
    Widget
);

typedef Boolean (*XtAcceptFocusProc)(
    Widget ,
    Time*
);

typedef void (*XtArgsProc)(
    Widget ,
    ArgList ,
    Cardinal*
);

typedef void (*XtInitProc)(
    Widget ,
    Widget ,
    ArgList ,
    Cardinal*
);

typedef Boolean (*XtSetValuesFunc)(
    Widget ,
    Widget ,
    Widget ,
    ArgList ,
    Cardinal*
);

typedef Boolean (*XtArgsFunc)(
    Widget ,
    ArgList ,
    Cardinal*
);

typedef void (*XtAlmostProc)(
    Widget ,
    Widget ,
    XtWidgetGeometry* ,
    XtWidgetGeometry*
);

typedef void (*XtExposeProc)(
    Widget ,
    XEvent* ,
    Region
);
typedef void (*XtRealizeProc)(
    Widget ,
    XtValueMask* ,
    XSetWindowAttributes*
);

typedef XtGeometryResult (*XtGeometryHandler)(
    Widget ,
    XtWidgetGeometry* ,
    XtWidgetGeometry*
);

typedef void (*XtStringProc)(
    Widget ,
    String
);

typedef struct {
    String name;
    String type;
    XtArgVal value;
    int size;
} XtTypedArg, *XtTypedArgList;

typedef void (*XtAllocateProc)(
    WidgetClass ,
    Cardinal * ,
    Cardinal * ,
    ArgList ,
    Cardinal * ,
    XtTypedArgList ,
    Cardinal * ,
    Widget * ,
    XtPointer *
);

typedef void (*XtDeallocateProc)(
    Widget ,
    XtPointer
);

struct _XtStateRec;

typedef struct _XtTMRec {
    XtTranslations translations;
    XtBoundActions proc_table;
    struct _XtStateRec *current_state;
    unsigned long lastEventTime;
} XtTMRec, *XtTM;









typedef struct _ObjectPart {
    Widget self;
    WidgetClass widget_class;
    Widget parent;
    XrmName xrm_name;
    Boolean being_destroyed;
    XtCallbackList destroy_callbacks;
    XtPointer constraints;
} ObjectPart;

typedef struct _ObjectRec {
    ObjectPart object;
} ObjectRec;
typedef struct _ObjectClassPart {

    WidgetClass superclass;
    String class_name;
    Cardinal widget_size;
    XtProc class_initialize;
    XtWidgetClassProc class_part_initialize;
    XtEnum class_inited;
    XtInitProc initialize;
    XtArgsProc initialize_hook;
    XtProc obj1;
    XtPointer obj2;
    Cardinal obj3;
    XtResourceList resources;
    Cardinal num_resources;
    XrmClass xrm_class;
    Boolean obj4;
    XtEnum obj5;
    Boolean obj6;
    Boolean obj7;
    XtWidgetProc destroy;
    XtProc obj8;
    XtProc obj9;
    XtSetValuesFunc set_values;
    XtArgsFunc set_values_hook;
    XtProc obj10;
    XtArgsProc get_values_hook;
    XtProc obj11;
    XtVersionType version;
    XtPointer callback_private;
    String obj12;
    XtProc obj13;
    XtProc obj14;
    XtPointer extension;
}ObjectClassPart;

typedef struct {
    XtPointer next_extension;
    XrmQuark record_type;
    long version;
    Cardinal record_size;
    XtAllocateProc allocate;
    XtDeallocateProc deallocate;
} ObjectClassExtensionRec, *ObjectClassExtension;

typedef struct _ObjectClassRec {
    ObjectClassPart object_class;
} ObjectClassRec;

extern ObjectClassRec objectClassRec;




typedef struct _CorePart {
    Widget self;
    WidgetClass widget_class;
    Widget parent;
    XrmName xrm_name;
    Boolean being_destroyed;
    XtCallbackList destroy_callbacks;
    XtPointer constraints;
    Position x, y;
    Dimension width, height;
    Dimension border_width;
    Boolean managed;
    Boolean sensitive;
    Boolean ancestor_sensitive;
    XtEventTable event_table;
    XtTMRec tm;
    XtTranslations accelerators;
    Pixel border_pixel;
    Pixmap border_pixmap;
    WidgetList popup_list;
    Cardinal num_popups;
    String name;
    Screen *screen;
    Colormap colormap;
    Window window;
    Cardinal depth;
    Pixel background_pixel;
    Pixmap background_pixmap;
    Boolean visible;
    Boolean mapped_when_managed;
} CorePart;

typedef struct _WidgetRec {
    CorePart core;
 } WidgetRec, CoreRec;

typedef struct _CoreClassPart {
    WidgetClass superclass;
    String class_name;
    Cardinal widget_size;
    XtProc class_initialize;
    XtWidgetClassProc class_part_initialize;
    XtEnum class_inited;
    XtInitProc initialize;
    XtArgsProc initialize_hook;
    XtRealizeProc realize;
    XtActionList actions;
    Cardinal num_actions;
    XtResourceList resources;
    Cardinal num_resources;
    XrmClass xrm_class;
    Boolean compress_motion;
    XtEnum compress_exposure;
    Boolean compress_enterleave;
    Boolean visible_interest;
    XtWidgetProc destroy;
    XtWidgetProc resize;
    XtExposeProc expose;
    XtSetValuesFunc set_values;
    XtArgsFunc set_values_hook;
    XtAlmostProc set_values_almost;
    XtArgsProc get_values_hook;
    XtAcceptFocusProc accept_focus;
    XtVersionType version;
    XtPointer callback_private;
    String tm_table;
    XtGeometryHandler query_geometry;
    XtStringProc display_accelerator;
    XtPointer extension;
 } CoreClassPart;

typedef struct _WidgetClassRec {
    CoreClassPart core_class;
} WidgetClassRec, CoreClassRec;










typedef struct _RectObjPart {
    Position x, y;
    Dimension width, height;
    Dimension border_width;
    Boolean managed;
    Boolean sensitive;
    Boolean ancestor_sensitive;
}RectObjPart;

typedef struct _RectObjRec {
    ObjectPart object;
    RectObjPart rectangle;
} RectObjRec;
typedef struct _RectObjClassPart {

    WidgetClass superclass;
    String class_name;
    Cardinal widget_size;
    XtProc class_initialize;
    XtWidgetClassProc class_part_initialize;
    XtEnum class_inited;
    XtInitProc initialize;
    XtArgsProc initialize_hook;
    XtProc rect1;
    XtPointer rect2;
    Cardinal rect3;
    XtResourceList resources;
    Cardinal num_resources;
    XrmClass xrm_class;
    Boolean rect4;
    XtEnum rect5;
    Boolean rect6;
    Boolean rect7;
    XtWidgetProc destroy;
    XtWidgetProc resize;
    XtExposeProc expose;
    XtSetValuesFunc set_values;
    XtArgsFunc set_values_hook;
    XtAlmostProc set_values_almost;
    XtArgsProc get_values_hook;
    XtProc rect9;
    XtVersionType version;
    XtPointer callback_private;
    String rect10;
    XtGeometryHandler query_geometry;
    XtProc rect11;
    XtPointer extension;
} RectObjClassPart;

typedef struct _RectObjClassRec {
    RectObjClassPart rect_class;
} RectObjClassRec;

extern RectObjClassRec rectObjClassRec;


extern Boolean XtIsRectObj(Widget);




extern Boolean XtIsWidget(Widget);




extern Boolean XtIsComposite(Widget);




extern Boolean XtIsConstraint(Widget);




extern Boolean XtIsShell(Widget);




extern Boolean XtIsWMShell(Widget);




extern Boolean XtIsTopLevelShell(Widget);


extern Widget _XtWindowedAncestor(
    Widget
);

extern void _XtInherit(
    void
);

extern void _XtHandleFocus(
    Widget ,
    XtPointer ,
    XEvent * ,
    Boolean * );

extern void XtCreateWindow(
    Widget ,
    unsigned int ,
    Visual* ,
    XtValueMask ,
    XSetWindowAttributes*
);

extern void XtResizeWidget(
    Widget ,
    Dimension ,
    Dimension ,
    Dimension
);

extern void XtMoveWidget(
    Widget ,
    Position ,
    Position
);

extern void XtConfigureWidget(
    Widget ,
    Position ,
    Position ,
    Dimension ,
    Dimension ,
    Dimension
);

extern void XtResizeWindow(
    Widget
);

extern void XtProcessLock(
    void
);

extern void XtProcessUnlock(
    void
);










extern void _XtResourceConfigurationEH(
 Widget ,
 XtPointer ,
 XEvent *
);









typedef void *IcePointer;

typedef enum {
    IcePoAuthHaveReply,
    IcePoAuthRejected,
    IcePoAuthFailed,
    IcePoAuthDoneCleanup
} IcePoAuthStatus;

typedef enum {
    IcePaAuthContinue,
    IcePaAuthAccepted,
    IcePaAuthRejected,
    IcePaAuthFailed
} IcePaAuthStatus;

typedef enum {
    IceConnectPending,
    IceConnectAccepted,
    IceConnectRejected,
    IceConnectIOError
} IceConnectStatus;

typedef enum {
    IceProtocolSetupSuccess,
    IceProtocolSetupFailure,
    IceProtocolSetupIOError,
    IceProtocolAlreadyActive
} IceProtocolSetupStatus;

typedef enum {
    IceAcceptSuccess,
    IceAcceptFailure,
    IceAcceptBadMalloc
} IceAcceptStatus;

typedef enum {
    IceClosedNow,
    IceClosedASAP,
    IceConnectionInUse,
    IceStartedShutdownNegotiation
} IceCloseStatus;

typedef enum {
    IceProcessMessagesSuccess,
    IceProcessMessagesIOError,
    IceProcessMessagesConnectionClosed
} IceProcessMessagesStatus;

typedef struct {
    unsigned long sequence_of_request;
    int major_opcode_of_request;
    int minor_opcode_of_request;
    IcePointer reply;
} IceReplyWaitInfo;

typedef struct _IceConn *IceConn;
typedef struct _IceListenObj *IceListenObj;

typedef void (*IceWatchProc) (
    IceConn ,
    IcePointer ,
    int ,
    IcePointer *
);

typedef void (*IcePoProcessMsgProc) (
    IceConn ,
    IcePointer ,
    int ,
    unsigned long ,
    int ,
    IceReplyWaitInfo * ,
    int *
);

typedef void (*IcePaProcessMsgProc) (
    IceConn ,
    IcePointer ,
    int ,
    unsigned long ,
    int
);

typedef struct {
    int major_version;
    int minor_version;
    IcePoProcessMsgProc process_msg_proc;
} IcePoVersionRec;

typedef struct {
    int major_version;
    int minor_version;
    IcePaProcessMsgProc process_msg_proc;
} IcePaVersionRec;

typedef IcePoAuthStatus (*IcePoAuthProc) (
    IceConn ,
    IcePointer * ,
    int ,
    int ,
    int ,
    IcePointer ,
    int * ,
    IcePointer * ,
    char **
);

typedef IcePaAuthStatus (*IcePaAuthProc) (
    IceConn ,
    IcePointer * ,
    int ,
    int ,
    IcePointer ,
    int * ,
    IcePointer * ,
    char **
);

typedef int (*IceHostBasedAuthProc) (
    char *
);

typedef int (*IceProtocolSetupProc) (
    IceConn ,
    int ,
    int ,
    char * ,
    char * ,
    IcePointer * ,
    char **
);

typedef void (*IceProtocolActivateProc) (
    IceConn ,
    IcePointer
);

typedef void (*IceIOErrorProc) (
    IceConn
);

typedef void (*IcePingReplyProc) (
    IceConn ,
    IcePointer
);

typedef void (*IceErrorHandler) (
    IceConn ,
    int ,
    int ,
    unsigned long ,
    int ,
    int ,
    IcePointer
);

typedef void (*IceIOErrorHandler) (
    IceConn
);








extern int IceRegisterForProtocolSetup (
    const char * ,
    const char * ,
    const char * ,
    int ,
    IcePoVersionRec * ,
    int ,
    const char ** ,
    IcePoAuthProc * ,
    IceIOErrorProc
);

extern int IceRegisterForProtocolReply (
    const char * ,
    const char * ,
    const char * ,
    int ,
    IcePaVersionRec * ,
    int ,
    const char ** ,
    IcePaAuthProc * ,
    IceHostBasedAuthProc ,
    IceProtocolSetupProc ,
    IceProtocolActivateProc ,
    IceIOErrorProc
);

extern IceConn IceOpenConnection (
    char * ,
    IcePointer ,
    int ,
    int ,
    int ,
    char *
);

extern IcePointer IceGetConnectionContext (
    IceConn
);

extern int IceListenForConnections (
    int * ,
    IceListenObj ** ,
    int ,
    char *
);

extern int IceListenForWellKnownConnections (
    char * ,
    int * ,
    IceListenObj ** ,
    int ,
    char *
);

extern int IceGetListenConnectionNumber (
    IceListenObj
);

extern char *IceGetListenConnectionString (
    IceListenObj
);

extern char *IceComposeNetworkIdList (
    int ,
    IceListenObj *
);

extern void IceFreeListenObjs (
    int ,
    IceListenObj *
);

extern void IceSetHostBasedAuthProc (
    IceListenObj ,
    IceHostBasedAuthProc
);

extern IceConn IceAcceptConnection (
    IceListenObj ,
    IceAcceptStatus *
);

extern void IceSetShutdownNegotiation (
    IceConn ,
    int
);

extern int IceCheckShutdownNegotiation (
    IceConn
);

extern IceCloseStatus IceCloseConnection (
    IceConn
);

extern int IceAddConnectionWatch (
    IceWatchProc ,
    IcePointer
);

extern void IceRemoveConnectionWatch (
    IceWatchProc ,
    IcePointer
);

extern IceProtocolSetupStatus IceProtocolSetup (
    IceConn ,
    int ,
    IcePointer ,
    int ,
    int * ,
    int * ,
    char ** ,
    char ** ,
    int ,
    char *
);

extern int IceProtocolShutdown (
    IceConn ,
    int
);

extern IceProcessMessagesStatus IceProcessMessages (
    IceConn ,
    IceReplyWaitInfo * ,
    int *
);

extern int IcePing (
   IceConn ,
   IcePingReplyProc ,
   IcePointer
);

extern char *IceAllocScratch (
   IceConn ,
   unsigned long
);

extern int IceFlush (
   IceConn
);

extern int IceGetOutBufSize (
   IceConn
);

extern int IceGetInBufSize (
   IceConn
);

extern IceConnectStatus IceConnectionStatus (
    IceConn
);

extern char *IceVendor (
    IceConn
);

extern char *IceRelease (
    IceConn
);

extern int IceProtocolVersion (
    IceConn
);

extern int IceProtocolRevision (
    IceConn
);

extern int IceConnectionNumber (
    IceConn
);

extern char *IceConnectionString (
    IceConn
);

extern unsigned long IceLastSentSequenceNumber (
    IceConn
);

extern unsigned long IceLastReceivedSequenceNumber (
    IceConn
);

extern int IceSwapping (
    IceConn
);

extern IceErrorHandler IceSetErrorHandler (
    IceErrorHandler
);

extern IceIOErrorHandler IceSetIOErrorHandler (
    IceIOErrorHandler
);

extern char *IceGetPeerName (
    IceConn
);





extern int IceInitThreads (
    void
);

extern void IceAppLockConn (
    IceConn
);

extern void IceAppUnlockConn (
    IceConn
);








typedef IcePointer SmPointer;






typedef struct _SmcConn *SmcConn;
typedef struct _SmsConn *SmsConn;






typedef struct {
    int length;
    SmPointer value;
} SmPropValue;

typedef struct {
    char *name;
    char *type;
    int num_vals;
    SmPropValue *vals;
} SmProp;







typedef enum {
    SmcClosedNow,
    SmcClosedASAP,
    SmcConnectionInUse
} SmcCloseStatus;







typedef void (*SmcSaveYourselfProc) (
    SmcConn ,
    SmPointer ,
    int ,
    int ,
    int ,
    int
);

typedef void (*SmcSaveYourselfPhase2Proc) (
    SmcConn ,
    SmPointer
);

typedef void (*SmcInteractProc) (
    SmcConn ,
    SmPointer
);

typedef void (*SmcDieProc) (
    SmcConn ,
    SmPointer
);

typedef void (*SmcShutdownCancelledProc) (
    SmcConn ,
    SmPointer
);

typedef void (*SmcSaveCompleteProc) (
    SmcConn ,
    SmPointer
);

typedef void (*SmcPropReplyProc) (
    SmcConn ,
    SmPointer ,
    int ,
    SmProp **
);






typedef struct {

    struct {
 SmcSaveYourselfProc callback;
 SmPointer client_data;
    } save_yourself;

    struct {
 SmcDieProc callback;
 SmPointer client_data;
    } die;

    struct {
 SmcSaveCompleteProc callback;
 SmPointer client_data;
    } save_complete;

    struct {
 SmcShutdownCancelledProc callback;
 SmPointer client_data;
    } shutdown_cancelled;

} SmcCallbacks;
typedef int (*SmsRegisterClientProc) (
    SmsConn ,
    SmPointer ,
    char *
);

typedef void (*SmsInteractRequestProc) (
    SmsConn ,
    SmPointer ,
    int
);

typedef void (*SmsInteractDoneProc) (
    SmsConn ,
    SmPointer ,
    int
);

typedef void (*SmsSaveYourselfRequestProc) (
    SmsConn ,
    SmPointer ,
    int ,
    int ,
    int ,
    int ,
    int
);

typedef void (*SmsSaveYourselfPhase2RequestProc) (
    SmsConn ,
    SmPointer
);

typedef void (*SmsSaveYourselfDoneProc) (
    SmsConn ,
    SmPointer ,
    int
);

typedef void (*SmsCloseConnectionProc) (
    SmsConn ,
    SmPointer ,
    int ,
    char **
);

typedef void (*SmsSetPropertiesProc) (
    SmsConn ,
    SmPointer ,
    int ,
    SmProp **
);

typedef void (*SmsDeletePropertiesProc) (
    SmsConn ,
    SmPointer ,
    int ,
    char **
);

typedef void (*SmsGetPropertiesProc) (
    SmsConn ,
    SmPointer
);






typedef struct {

    struct {
 SmsRegisterClientProc callback;
 SmPointer manager_data;
    } register_client;

    struct {
 SmsInteractRequestProc callback;
 SmPointer manager_data;
    } interact_request;

    struct {
 SmsInteractDoneProc callback;
 SmPointer manager_data;
    } interact_done;

    struct {
 SmsSaveYourselfRequestProc callback;
 SmPointer manager_data;
    } save_yourself_request;

    struct {
 SmsSaveYourselfPhase2RequestProc callback;
 SmPointer manager_data;
    } save_yourself_phase2_request;

    struct {
 SmsSaveYourselfDoneProc callback;
 SmPointer manager_data;
    } save_yourself_done;

    struct {
 SmsCloseConnectionProc callback;
 SmPointer manager_data;
    } close_connection;

    struct {
 SmsSetPropertiesProc callback;
 SmPointer manager_data;
    } set_properties;

    struct {
 SmsDeletePropertiesProc callback;
 SmPointer manager_data;
    } delete_properties;

    struct {
 SmsGetPropertiesProc callback;
 SmPointer manager_data;
    } get_properties;

} SmsCallbacks;
typedef int (*SmsNewClientProc) (
    SmsConn ,
    SmPointer ,
    unsigned long * ,
    SmsCallbacks * ,
    char **
);







typedef void (*SmcErrorHandler) (
    SmcConn ,
    int ,
    int ,
    unsigned long ,
    int ,
    int ,
    SmPointer
);

typedef void (*SmsErrorHandler) (
    SmsConn ,
    int ,
    int ,
    unsigned long ,
    int ,
    int ,
    SmPointer
);









extern SmcConn SmcOpenConnection (
    char * ,
    SmPointer ,
    int ,
    int ,
    unsigned long ,
    SmcCallbacks * ,
    char * ,
    char ** ,
    int ,
    char *
);

extern SmcCloseStatus SmcCloseConnection (
    SmcConn ,
    int ,
    char **
);

extern void SmcModifyCallbacks (
    SmcConn ,
    unsigned long ,
    SmcCallbacks *
);

extern void SmcSetProperties (
    SmcConn ,
    int ,
    SmProp **
);

extern void SmcDeleteProperties (
    SmcConn ,
    int ,
    char **
);

extern int SmcGetProperties (
    SmcConn ,
    SmcPropReplyProc ,
    SmPointer
);

extern int SmcInteractRequest (
    SmcConn ,
    int ,
    SmcInteractProc ,
    SmPointer
);

extern void SmcInteractDone (
    SmcConn ,
    int
);

extern void SmcRequestSaveYourself (
    SmcConn ,
    int ,
    int ,
    int ,
    int ,
    int
);

extern int SmcRequestSaveYourselfPhase2 (
    SmcConn ,
    SmcSaveYourselfPhase2Proc ,
    SmPointer
);

extern void SmcSaveYourselfDone (
    SmcConn ,
    int
);

extern int SmcProtocolVersion (
    SmcConn
);

extern int SmcProtocolRevision (
    SmcConn
);

extern char *SmcVendor (
    SmcConn
);

extern char *SmcRelease (
    SmcConn
);

extern char *SmcClientID (
    SmcConn
);

extern IceConn SmcGetIceConnection (
    SmcConn
);

extern int SmsInitialize (
    const char * ,
    const char * ,
    SmsNewClientProc ,
    SmPointer ,
    IceHostBasedAuthProc ,
    int ,
    char *
);

extern char *SmsClientHostName (
    SmsConn
);

extern char *SmsGenerateClientID (
    SmsConn
);

extern int SmsRegisterClientReply (
    SmsConn ,
    char *
);

extern void SmsSaveYourself (
    SmsConn ,
    int ,
    int ,
    int ,
    int
);

extern void SmsSaveYourselfPhase2 (
    SmsConn
);

extern void SmsInteract (
    SmsConn
);

extern void SmsDie (
    SmsConn
);

extern void SmsSaveComplete (
    SmsConn
);

extern void SmsShutdownCancelled (
    SmsConn
);

extern void SmsReturnProperties (
    SmsConn ,
    int ,
    SmProp **
);

extern void SmsCleanUp (
    SmsConn
);

extern int SmsProtocolVersion (
    SmsConn
);

extern int SmsProtocolRevision (
    SmsConn
);

extern char *SmsClientID (
    SmsConn
);

extern IceConn SmsGetIceConnection (
    SmsConn
);

extern SmcErrorHandler SmcSetErrorHandler (
    SmcErrorHandler
);

extern SmsErrorHandler SmsSetErrorHandler (
    SmsErrorHandler
);

extern void SmFreeProperty (
    SmProp *
);

extern void SmFreeReasons (
    int ,
    char **
);


extern const char XtShellStrings[];
typedef struct _ShellClassRec *ShellWidgetClass;
typedef struct _OverrideShellClassRec *OverrideShellWidgetClass;
typedef struct _WMShellClassRec *WMShellWidgetClass;
typedef struct _TransientShellClassRec *TransientShellWidgetClass;
typedef struct _TopLevelShellClassRec *TopLevelShellWidgetClass;
typedef struct _ApplicationShellClassRec *ApplicationShellWidgetClass;
typedef struct _SessionShellClassRec *SessionShellWidgetClass;


extern WidgetClass shellWidgetClass;
extern WidgetClass overrideShellWidgetClass;
extern WidgetClass wmShellWidgetClass;
extern WidgetClass transientShellWidgetClass;
extern WidgetClass topLevelShellWidgetClass;
extern WidgetClass applicationShellWidgetClass;
extern WidgetClass sessionShellWidgetClass;








typedef struct {
    XtPointer extension;
} ShellClassPart;

typedef struct {
    XtPointer next_extension;
    XrmQuark record_type;
    long version;
    Cardinal record_size;
    XtGeometryHandler root_geometry_manager;
} ShellClassExtensionRec, *ShellClassExtension;






typedef struct _CompositePart {
    WidgetList children;
    Cardinal num_children;
    Cardinal num_slots;
    XtOrderProc insert_position;
} CompositePart,*CompositePtr;

typedef struct _CompositeRec {
    CorePart core;
    CompositePart composite;
} CompositeRec;







typedef struct _CompositeClassPart {
    XtGeometryHandler geometry_manager;
    XtWidgetProc change_managed;
    XtWidgetProc insert_child;
    XtWidgetProc delete_child;
    XtPointer extension;
} CompositeClassPart,*CompositePartPtr;

typedef struct {
    XtPointer next_extension;
    XrmQuark record_type;
    long version;
    Cardinal record_size;
    Boolean accepts_objects;
    Boolean allows_change_managed_set;
} CompositeClassExtensionRec, *CompositeClassExtension;


typedef struct _CompositeClassRec {
     CoreClassPart core_class;
     CompositeClassPart composite_class;
} CompositeClassRec;






typedef struct _ConstraintClassRec *ConstraintWidgetClass;



typedef struct _ConstraintClassPart {
    XtResourceList resources;
    Cardinal num_resources;
    Cardinal constraint_size;
    XtInitProc initialize;
    XtWidgetProc destroy;
    XtSetValuesFunc set_values;
    XtPointer extension;
} ConstraintClassPart;

typedef struct {
    XtPointer next_extension;
    XrmQuark record_type;
    long version;
    Cardinal record_size;
    XtArgsProc get_values_hook;
} ConstraintClassExtensionRec, *ConstraintClassExtension;

typedef struct _ConstraintClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    ConstraintClassPart constraint_class;
} ConstraintClassRec;



typedef struct _WidgetClassRec *CoreWidgetClass;
typedef struct _WidgetRec *CoreWidget;




typedef struct _ConstraintPart {
    XtPointer mumble;
} ConstraintPart;

typedef struct _ConstraintRec {
    CorePart core;
    CompositePart composite;
    ConstraintPart constraint;
} ConstraintRec, *ConstraintWidget;




typedef struct _ShellClassRec {
   CoreClassPart core_class;
 CompositeClassPart composite_class;
 ShellClassPart shell_class;
} ShellClassRec;

extern ShellClassRec shellClassRec;



typedef struct {
 char *geometry;
 XtCreatePopupChildProc create_popup_child_proc;
 XtGrabKind grab_kind;
 Boolean spring_loaded;
 Boolean popped_up;
 Boolean allow_shell_resize;
 Boolean client_specified;




 Boolean save_under;
 Boolean override_redirect;

 XtCallbackList popup_callback;
 XtCallbackList popdown_callback;
 Visual* visual;
} ShellPart;

typedef struct {
 CorePart core;
 CompositePart composite;
 ShellPart shell;
} ShellRec, *ShellWidget;
typedef struct {
    XtPointer extension;
} OverrideShellClassPart;

typedef struct _OverrideShellClassRec {
   CoreClassPart core_class;
 CompositeClassPart composite_class;
 ShellClassPart shell_class;
 OverrideShellClassPart override_shell_class;
} OverrideShellClassRec;

extern OverrideShellClassRec overrideShellClassRec;



typedef struct {int frabjous;} OverrideShellPart;

typedef struct {
 CorePart core;
 CompositePart composite;
 ShellPart shell;
 OverrideShellPart override;
} OverrideShellRec, *OverrideShellWidget;
typedef struct {
    XtPointer extension;
} WMShellClassPart;

typedef struct _WMShellClassRec {
   CoreClassPart core_class;
 CompositeClassPart composite_class;
 ShellClassPart shell_class;
 WMShellClassPart wm_shell_class;
} WMShellClassRec;

extern WMShellClassRec wmShellClassRec;



typedef struct {
 char *title;
 int wm_timeout;
 Boolean wait_for_wm;
 Boolean transient;
 Boolean urgency;
 Widget client_leader;
 String window_role;
 struct _OldXSizeHints {
     long flags;
     int x, y;
     int width, height;
     int min_width, min_height;
     int max_width, max_height;
     int width_inc, height_inc;
     struct {
      int x;
      int y;
     } min_aspect, max_aspect;
 } size_hints;
 XWMHints wm_hints;
 int base_width, base_height;
 int win_gravity;
 Atom title_encoding;
} WMShellPart;

typedef struct {
 CorePart core;
 CompositePart composite;
 ShellPart shell;
 WMShellPart wm;
} WMShellRec, *WMShellWidget;



typedef struct _VendorShellClassRec *VendorShellWidgetClass;



extern WidgetClass vendorShellWidgetClass;







typedef struct {
    XtPointer extension;
} VendorShellClassPart;

typedef struct _VendorShellClassRec {
   CoreClassPart core_class;
 CompositeClassPart composite_class;
 ShellClassPart shell_class;
 WMShellClassPart wm_shell_class;
 VendorShellClassPart vendor_shell_class;
} VendorShellClassRec;

extern VendorShellClassRec vendorShellClassRec;



typedef struct {
 int vendor_specific;
} VendorShellPart;

typedef struct {
 CorePart core;
 CompositePart composite;
 ShellPart shell;
 WMShellPart wm;
 VendorShellPart vendor;
} VendorShellRec, *VendorShellWidget;




typedef struct {
    XtPointer extension;
} TransientShellClassPart;

typedef struct _TransientShellClassRec {
   CoreClassPart core_class;
 CompositeClassPart composite_class;
 ShellClassPart shell_class;
 WMShellClassPart wm_shell_class;
 VendorShellClassPart vendor_shell_class;
 TransientShellClassPart transient_shell_class;
} TransientShellClassRec;

extern TransientShellClassRec transientShellClassRec;



typedef struct {
 Widget transient_for;
} TransientShellPart;

typedef struct {
 CorePart core;
 CompositePart composite;
 ShellPart shell;
 WMShellPart wm;
 VendorShellPart vendor;
 TransientShellPart transient;
} TransientShellRec, *TransientShellWidget;
typedef struct {
    XtPointer extension;
} TopLevelShellClassPart;

typedef struct _TopLevelShellClassRec {
   CoreClassPart core_class;
 CompositeClassPart composite_class;
 ShellClassPart shell_class;
 WMShellClassPart wm_shell_class;
 VendorShellClassPart vendor_shell_class;
 TopLevelShellClassPart top_level_shell_class;
} TopLevelShellClassRec;

extern TopLevelShellClassRec topLevelShellClassRec;



typedef struct {
 char *icon_name;
 Boolean iconic;
 Atom icon_name_encoding;
} TopLevelShellPart;

typedef struct {
 CorePart core;
 CompositePart composite;
 ShellPart shell;
 WMShellPart wm;
 VendorShellPart vendor;
 TopLevelShellPart topLevel;
} TopLevelShellRec, *TopLevelShellWidget;
typedef struct {
    XtPointer extension;
} ApplicationShellClassPart;

typedef struct _ApplicationShellClassRec {
   CoreClassPart core_class;
 CompositeClassPart composite_class;
 ShellClassPart shell_class;
 WMShellClassPart wm_shell_class;
 VendorShellClassPart vendor_shell_class;
 TopLevelShellClassPart top_level_shell_class;
 ApplicationShellClassPart application_shell_class;
} ApplicationShellClassRec;

extern ApplicationShellClassRec applicationShellClassRec;



typedef struct {
    char *_class;

    XrmClass xrm_class;
    int argc;
    char **argv;
} ApplicationShellPart;

typedef struct {
 CorePart core;
 CompositePart composite;
 ShellPart shell;
 WMShellPart wm;
 VendorShellPart vendor;
 TopLevelShellPart topLevel;
 ApplicationShellPart application;
} ApplicationShellRec, *ApplicationShellWidget;
typedef struct {
    XtPointer extension;
} SessionShellClassPart;

typedef struct _SessionShellClassRec {
   CoreClassPart core_class;
 CompositeClassPart composite_class;
 ShellClassPart shell_class;
 WMShellClassPart wm_shell_class;
 VendorShellClassPart vendor_shell_class;
 TopLevelShellClassPart top_level_shell_class;
 ApplicationShellClassPart application_shell_class;
 SessionShellClassPart session_shell_class;
} SessionShellClassRec;

extern SessionShellClassRec sessionShellClassRec;

typedef struct _XtSaveYourselfRec *XtSaveYourself;



typedef struct {
    SmcConn connection;
    String session_id;
    String* restart_command;
    String* clone_command;
    String* discard_command;
    String* resign_command;
    String* shutdown_command;
    String* environment;
    String current_dir;
    String program_path;
    unsigned char restart_style;
    unsigned char checkpoint_state;
    Boolean join_session;
    XtCallbackList save_callbacks;
    XtCallbackList interact_callbacks;
    XtCallbackList cancel_callbacks;
    XtCallbackList save_complete_callbacks;
    XtCallbackList die_callbacks;
    XtCallbackList error_callbacks;
    XtSaveYourself save;
    XtInputId input_id;
    XtPointer ses20;
    XtPointer ses19;
    XtPointer ses18;
    XtPointer ses17;
    XtPointer ses16;
    XtPointer ses15;
    XtPointer ses14;
    XtPointer ses13;
    XtPointer ses12;
    XtPointer ses11;
    XtPointer ses10;
    XtPointer ses9;
    XtPointer ses8;
    XtPointer ses7;
    XtPointer ses6;
    XtPointer ses5;
    XtPointer ses4;
    XtPointer ses3;
    XtPointer ses2;
    XtPointer ses1;
} SessionShellPart;

typedef struct {
 CorePart core;
 CompositePart composite;
 ShellPart shell;
 WMShellPart wm;
 VendorShellPart vendor;
 TopLevelShellPart topLevel;
 ApplicationShellPart application;
 SessionShellPart session;
} SessionShellRec, *SessionShellWidget;




typedef struct _XmuWidgetNode {
    char *label;
    WidgetClass *widget_class_ptr;
    struct _XmuWidgetNode *superclass;
    struct _XmuWidgetNode *children, *siblings;
    char *lowered_label;
    char *lowered_classname;
    int have_resources;
    XtResourceList resources;
    struct _XmuWidgetNode **resourcewn;
    Cardinal nresources;
    XtResourceList constraints;
    struct _XmuWidgetNode **constraintwn;
    Cardinal nconstraints;
    XtPointer data;
} XmuWidgetNode;








void XmuWnInitializeNodes
(
 XmuWidgetNode *nodearray,
 int nnodes
 );

void XmuWnFetchResources
(
 XmuWidgetNode *node,
 Widget toplevel,
 XmuWidgetNode *topnode
 );

int XmuWnCountOwnedResources
(
 XmuWidgetNode *node,
 XmuWidgetNode *ownernode,
 int constraints
 );

XmuWidgetNode *XmuWnNameToNode
(
 XmuWidgetNode *nodelist,
 int nnodes,
 const char *name
 );






extern XmuWidgetNode XawWidgetArray[];
extern int XawWidgetCount;


void XmuCvtFunctionToCallback
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );
void XmuCvtStringToBackingStore
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );

Boolean XmuCvtBackingStoreToString
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal,
 XtPointer *converter_data
 );

void XmuCvtStringToCursor
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );




Boolean XmuCvtStringToColorCursor
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal,
 XtPointer *converter_data
 );

typedef int XtGravity;
void XmuCvtStringToGravity
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );

Boolean XmuCvtGravityToString
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal,
 XtPointer *converter_data
 );

typedef enum {
    XtJustifyLeft,
    XtJustifyCenter,
    XtJustifyRight
} XtJustify;
void XmuCvtStringToJustify
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );

Boolean XmuCvtJustifyToString
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal,
 XtPointer *converter_data
 );


void XmuCvtStringToLong
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );
Boolean XmuCvtLongToString
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal,
 XtPointer *converter_data
 );

typedef enum {
  XtorientHorizontal,
  XtorientVertical
} XtOrientation;
void XmuCvtStringToOrientation
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );

Boolean XmuCvtOrientationToString
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal,
 XtPointer *converter_data
 );

void XmuCvtStringToBitmap
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );
Boolean XmuCvtStringToShapeStyle
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal,
 XtPointer *converter_data
 );

Boolean XmuCvtShapeStyleToString
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal,
 XtPointer *converter_data
 );

Boolean XmuReshapeWidget
(
 Widget w,
 int shape_style,
 int corner_width,
 int corner_height
 );

void XmuCvtStringToWidget
(
 XrmValue *args,
 Cardinal *num_args,
 XrmValuePtr fromVal,
 XrmValuePtr toVal
 );

Boolean XmuNewCvtStringToWidget
(
 Display *display,
 XrmValue *args,
 Cardinal *num_args,
 XrmValue *fromVal,
 XrmValue *toVal,
 XtPointer *converter_data
 );

Boolean XmuCvtWidgetToString
(
 Display *dpy,
 XrmValue *args,
 Cardinal *num_args,
 XrmValue *fromVal,
 XrmValue *toVal,
 XtPointer *converter_data
 );


typedef struct _SimpleClassRec *SimpleWidgetClass;
typedef struct _SimpleRec *SimpleWidget;

extern WidgetClass simpleWidgetClass;
typedef long XawTextPosition;


typedef enum {
  XawtextScrollNever,
  XawtextScrollWhenNeeded,
  XawtextScrollAlways
} XawTextScrollMode;

typedef enum {
  XawtextResizeNever,
  XawtextResizeWidth,
  XawtextResizeHeight,
  XawtextResizeBoth
} XawTextResizeMode;


typedef enum {
  XawtextWrapNever,
  XawtextWrapLine,
  XawtextWrapWord
} XawTextWrapMode;

typedef enum {
  XawsdLeft,
  XawsdRight
} XawTextScanDirection;

typedef enum {
  XawtextRead,
  XawtextAppend,
  XawtextEdit
} XawTextEditType;

typedef enum {
  XawselectNull,
  XawselectPosition,
  XawselectChar,
  XawselectWord,
  XawselectLine,
  XawselectParagraph,
  XawselectAll,
  XawselectAlphaNumeric
} XawTextSelectType;

typedef enum {
    XawjustifyLeft,
    XawjustifyRight,
    XawjustifyCenter,
    XawjustifyFull
} XawTextJustifyMode;

typedef struct {
    int firstPos;
    int length;
    char *ptr;
    unsigned long format;
} XawTextBlock, *XawTextBlockPtr;


typedef struct {
    int line_number;
    int column_number;
    XawTextPosition insert_position;
    XawTextPosition last_position;
    Boolean overwrite_mode;
} XawTextPositionInfo;

typedef struct {
    XawTextPosition left, right;
    XawTextBlock *block;
} XawTextPropertyInfo;

typedef struct _XawTextAnchor XawTextAnchor;
typedef struct _XawTextEntity XawTextEntity;
typedef struct _XawTextProperty XawTextProperty;
typedef struct _XawTextPropertyList XawTextPropertyList;


extern WidgetClass textSrcObjectClass;

typedef struct _TextSrcClassRec *TextSrcObjectClass;
typedef struct _TextSrcRec *TextSrcObject;

typedef enum {
    XawstPositions,
    XawstWhiteSpace,
    XawstEOL,
    XawstParagraph,
    XawstAll,
    XawstAlphaNumeric
  } XawTextScanType;

typedef enum {
    Normal,
    Selected
} highlightType;

typedef enum {
    XawsmTextSelect,
    XawsmTextExtend
} XawTextSelectionMode;

typedef enum {
    XawactionStart,
    XawactionAdjust,
    XawactionEnd
} XawTextSelectionAction;

XawTextPosition XawTextSourceRead
(
 Widget w,
 XawTextPosition pos,
 XawTextBlock *text_return,
 int length
 );
int XawTextSourceReplace
(
 Widget w,
 XawTextPosition start,
 XawTextPosition end,
 XawTextBlock *text
 );
XawTextPosition XawTextSourceScan
(
 Widget w,
 XawTextPosition position,






 XawTextScanType type,
 XawTextScanDirection dir,
 int count,
 Boolean include

 );
XawTextPosition XawTextSourceSearch
(
 Widget w,
 XawTextPosition position,



 XawTextScanDirection dir,

 XawTextBlock *text
 );
Boolean XawTextSourceConvertSelection
(
 Widget w,
 Atom *selection,
 Atom *target,
 Atom *type,
 XtPointer *value_return,
 unsigned long *length_return,
 int *format_return
 );
void XawTextSourceSetSelection
(
 Widget w,
 XawTextPosition start,
 XawTextPosition end,
 Atom selection
 );


extern unsigned long FMT8BIT;
extern unsigned long XawFmt8Bit;
extern unsigned long XawFmtWide;

extern WidgetClass textWidgetClass;

typedef struct _TextClassRec *TextWidgetClass;
typedef struct _TextRec *TextWidget;



XrmQuark _XawTextFormat
(
 TextWidget tw
 );

void XawTextDisplay
(
 Widget w
 );

void XawTextEnableRedisplay
(
 Widget w
 );

void XawTextDisableRedisplay
(
 Widget w
 );

void XawTextSetSelectionArray
(
 Widget w,
 XawTextSelectType *sarray
 );

void XawTextGetSelectionPos
(
 Widget w,
 XawTextPosition *begin_return,
 XawTextPosition *end_return
 );

void XawTextSetSource
(
 Widget w,
 Widget source,
 XawTextPosition top
 );

int XawTextReplace
(
 Widget w,
 XawTextPosition start,
 XawTextPosition end,
 XawTextBlock *text
 );

XawTextPosition XawTextTopPosition
(
 Widget w
 );

XawTextPosition XawTextLastPosition
(
 Widget w
 );

void XawTextSetInsertionPoint
(
 Widget w,
 XawTextPosition position
 );

XawTextPosition XawTextGetInsertionPoint
(
 Widget w
 );

void XawTextUnsetSelection
(
 Widget w
 );

void XawTextSetSelection
(
 Widget w,
 XawTextPosition left,
 XawTextPosition right
 );

void XawTextInvalidate
(
 Widget w,
 XawTextPosition from,
 XawTextPosition to
);

Widget XawTextGetSource
(
 Widget w
 );

Widget XawTextGetSink
(
 Widget w
 );

XawTextPosition XawTextSearch
(
 Widget w,



 XawTextScanDirection dir,

 XawTextBlock *text
 );

void XawTextDisplayCaret
(
 Widget w,



 Boolean visible

 );






extern WidgetClass asciiSrcObjectClass;

typedef struct _AsciiSrcClassRec *AsciiSrcObjectClass;
typedef struct _AsciiSrcRec *AsciiSrcObject;
typedef enum {
  XawAsciiFile,
  XawAsciiString
} XawAsciiType;






void XawAsciiSourceFreeString
(
 Widget w
 );
int XawAsciiSave
(
 Widget w
 );
int XawAsciiSaveAsFile
(
 Widget w,
 const char *name
 );
int XawAsciiSourceChanged
(
 Widget w
 );


extern WidgetClass textSinkObjectClass;

typedef struct _TextSinkClassRec *TextSinkObjectClass;
typedef struct _TextSinkRec *TextSinkObject;

typedef enum {XawisOn, XawisOff} XawTextInsertState;

void XawTextSinkDisplayText
(
 Widget w,




 Position x,
 Position y,

 XawTextPosition pos1,
 XawTextPosition pos2,



 Boolean highlight

 );
void XawTextSinkInsertCursor
(
 Widget w,





 Position x,
 Position y,
 XawTextInsertState state

 );
void XawTextSinkClearToBackground
(
 Widget w,






 Position x,
 Position y,
 Dimension width,
 Dimension height

 );
void XawTextSinkFindPosition
(
 Widget w,
 XawTextPosition fromPos,
 int fromX,
 int width,



 Boolean stopAtWordBreak,

 XawTextPosition* pos_return,
 int *width_return,
 int *height_return
 );
void XawTextSinkFindDistance
(
 Widget w,
 XawTextPosition fromPos,
 int fromX,
 XawTextPosition toPos,
 int *width_return,
 XawTextPosition *pos_return,
 int *height_return
 );
void XawTextSinkResolve
(
 Widget w,
 XawTextPosition fromPos,
 int fromX,
 int width,
 XawTextPosition *pos_return
 );
int XawTextSinkMaxLines
(
 Widget w,



 Dimension height

 );
int XawTextSinkMaxHeight
(
 Widget w,
 int lines
);
void XawTextSinkSetTabs
(
 Widget w,
 int tab_count,
 int *tabs
);
void XawTextSinkGetCursorBounds
(
 Widget w,
 XRectangle *rect_return
);


extern WidgetClass asciiSinkObjectClass;

typedef struct _AsciiSinkClassRec *AsciiSinkObjectClass;
typedef struct _AsciiSinkRec *AsciiSinkObject;


typedef struct _XawDL XawDisplayList;







void XawInitializeWidgetSet(void);

void XawInitializeDefaultConverters(void);


extern Widget XawOpenApplication(
    XtAppContext *app_context_return,
    Display *dpy,
    Screen *screen,
    String application_name,
    String application_class,
    WidgetClass widget_class,
    int *argc,
    String *argv
);



typedef struct {
    int (*change_sensitive)(Widget);

    XtPointer extension;

} SimpleClassPart;



typedef struct _SimpleClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
} SimpleClassRec;

extern SimpleClassRec simpleClassRec;

typedef struct {

    Cursor cursor;
    Pixmap insensitive_border;
    String cursor_name;
    Pixel pointer_fg, pointer_bg;
    Boolean international;



    XawDisplayList *display_list;
    String tip;
    XtPointer pad[3];

} SimplePart;

typedef struct _SimpleRec {
    CorePart core;
    SimplePart simple;
} SimpleRec;




extern XtActionsRec _XawTextActionsTable[];
extern Cardinal _XawTextActionsTableCount;

extern char _XawDefaultTextTranslations[];
typedef struct {
    XawTextPosition position;
    Position y;

    unsigned int textWidth;



} XawTextLineTableEntry, *XawTextLineTableEntryPtr;

typedef struct {
    XawTextPosition left, right;
    XawTextSelectType type;
    Atom *selections;
    int atom_count;
    int array_size;
} XawTextSelection;

typedef struct _XawTextSelectionSalt {
    struct _XawTextSelectionSalt *next;
    XawTextSelection s;




    char *contents;
    int length;
} XawTextSelectionSalt;


typedef struct _XawTextKillRing {
    struct _XawTextKillRing *next;
    char *contents;
    int length;
    unsigned refcount;
    unsigned long format;
} XawTextKillRing;

extern XawTextKillRing *xaw_text_kill_ring;



typedef struct {
    XawTextPosition top;
    int lines;

    int base_line;

    XawTextLineTableEntry *info;
} XawTextLineTable, *XawTextLineTablePtr;

typedef struct _XawTextMargin {
    Position left, right, top, bottom;
} XawTextMargin;

typedef struct _XmuScanline XmuTextUpdate;
struct SearchAndReplace {
    Boolean selection_changed;

    Widget search_popup;
    Widget label1;
    Widget label2;
    Widget left_toggle;
    Widget right_toggle;
    Widget rep_label;
    Widget rep_text;
    Widget search_text;
    Widget rep_one;
    Widget rep_all;

    Widget case_sensitive;

};


typedef struct {
  XtPointer extension;
} TextClassPart;


typedef struct _TextClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    TextClassPart text_class;
} TextClassRec;

extern TextClassRec textClassRec;


typedef struct _TextPart {

    Widget source, sink;
    XawTextPosition insertPos;
    XawTextSelection s;
    XawTextSelectType *sarray;
    XawTextSelectionSalt *salt;
    int left_margin;
    int dialog_horiz_offset, dialog_vert_offset;
    Boolean display_caret;
    Boolean auto_fill;
    XawTextScrollMode scroll_vert, scroll_horiz;
    XawTextWrapMode wrap;
    XawTextResizeMode resize;
    XawTextMargin r_margin;

    XtCallbackList position_callbacks;





    XawTextMargin margin;
    XawTextLineTable lt;
    XawTextScanDirection extendDir;
    XawTextSelection origSel;
    Time lasttime;
    Time time;
    Position ev_x, ev_y;
    Widget vbar, hbar;
    struct SearchAndReplace *search;
    Widget file_insert;
    XmuTextUpdate *update;

    int line_number;
    short column_number;
    unsigned char kill_ring;
    Boolean selection_state;




    int from_left;
    XawTextPosition lastPos;
    GC gc;
    Boolean showposition;
    Boolean hasfocus;
    Boolean update_disabled;
    Boolean clear_to_eol;
    XawTextPosition old_insert;
    short mult;

    XawTextKillRing *kill_ring_ptr;





    Boolean redisplay_needed;
    XawTextSelectionSalt *salt2;


    char numeric;
    char source_changed;
    Boolean overwrite;




    short left_column, right_column;
    XawTextJustifyMode justify;
    XtPointer pad[4];

} TextPart;







typedef struct _TextRec {
    CorePart core;
    SimplePart simple;
    TextPart text;
} TextRec;





void _XawTextBuildLineTable
(
 TextWidget ctx,
 XawTextPosition top_pos,
 Boolean force_rebuild
 );

char *_XawTextGetSTRING
(
 TextWidget ctx,
 XawTextPosition left,
 XawTextPosition right
 );

void _XawTextSaltAwaySelection
(
 TextWidget ctx,
 Atom *selections,
 int num_atoms
 );

void _XawTextPosToXY
(
 Widget w,
 XawTextPosition pos,
 Position *x,
 Position *y
 );

void _XawTextNeedsUpdating
(
 TextWidget ctx,
 XawTextPosition left,
 XawTextPosition right
 );





struct _XawTextAnchor {
    XawTextPosition position;
    XawTextEntity *entities, *cache;
};




struct _XawTextEntity {
    short type;
    short flags;
    XawTextEntity *next;
    XtPointer data;
    XawTextPosition offset;
    Cardinal length;
    XrmQuark property;
};
typedef XawTextPosition (*_XawSrcReadProc)
     (Widget, XawTextPosition, XawTextBlock*, int);

typedef int (*_XawSrcReplaceProc)
     (Widget, XawTextPosition, XawTextPosition, XawTextBlock*);

typedef XawTextPosition (*_XawSrcScanProc)
     (Widget, XawTextPosition, XawTextScanType, XawTextScanDirection,
      int, int);

typedef XawTextPosition (*_XawSrcSearchProc)
     (Widget, XawTextPosition, XawTextScanDirection, XawTextBlock*);

typedef void (*_XawSrcSetSelectionProc)
     (Widget, XawTextPosition, XawTextPosition, Atom);

typedef Boolean (*_XawSrcConvertSelectionProc)
     (Widget, Atom*, Atom*, Atom*, XtPointer*, unsigned long*, int*);

typedef struct _TextSrcClassPart {
    _XawSrcReadProc Read;
    _XawSrcReplaceProc Replace;
    _XawSrcScanProc Scan;
    _XawSrcSearchProc Search;
    _XawSrcSetSelectionProc SetSelection;
    _XawSrcConvertSelectionProc ConvertSelection;

    XtPointer extension;

} TextSrcClassPart;


typedef struct _TextSrcClassRec {
    ObjectClassPart object_class;
    TextSrcClassPart textSrc_class;
} TextSrcClassRec;

extern TextSrcClassRec textSrcClassRec;


typedef struct _XawTextUndo XawTextUndo;



typedef struct {

    XawTextEditType edit_mode;
    XrmQuark text_format;


    XtCallbackList callback;

    Boolean changed;
    Boolean enable_undo;


    Boolean undo_state;
    XawTextUndo *undo;
    WidgetList text;
    Cardinal num_text;
    XtCallbackList property_callback;
    XawTextAnchor **anchors;
    int num_anchors;
    XtPointer pad[1];

} TextSrcPart;


typedef struct _TextSrcRec {
    ObjectPart object;
    TextSrcPart textSrc;
} TextSrcRec;




char* _XawTextWCToMB
(
 Display *display,
 wchar_t *wstr,
 int *len_in_out
 );

wchar_t* _XawTextMBToWC
(
 Display *display,
 char *str,
 int *len_in_out
 );


XawTextAnchor *XawTextSourceAddAnchor
(
 Widget source,
 XawTextPosition position
 );

XawTextAnchor *XawTextSourceFindAnchor
(
 Widget source,
 XawTextPosition position
 );

XawTextAnchor *XawTextSourceNextAnchor
(
 Widget source,
 XawTextAnchor *anchor
 );

XawTextAnchor *XawTextSourcePrevAnchor
(
 Widget source,
 XawTextAnchor *anchor
 );

XawTextAnchor *XawTextSourceRemoveAnchor
(
 Widget source,
 XawTextAnchor *anchor
 );

int XawTextSourceAnchorAndEntity
(
 Widget w,
 XawTextPosition position,
 XawTextAnchor **anchor_return,
 XawTextEntity **entity_return
 );

XawTextEntity *XawTextSourceAddEntity
(
 Widget source,
 int type,
 int flags,
 XtPointer data,
 XawTextPosition position,
 Cardinal length,
 XrmQuark property
 );

void XawTextSourceClearEntities
(
 Widget w,
 XawTextPosition left,
 XawTextPosition right
 );

typedef struct _AtomRec *AtomPtr;

extern AtomPtr
    _XA_ATOM_PAIR,
    _XA_CHARACTER_POSITION,
    _XA_CLASS,
    _XA_CLIENT_WINDOW,
    _XA_CLIPBOARD,
    _XA_COMPOUND_TEXT,
    _XA_DECNET_ADDRESS,
    _XA_DELETE,
    _XA_FILENAME,
    _XA_HOSTNAME,
    _XA_IP_ADDRESS,
    _XA_LENGTH,
    _XA_LIST_LENGTH,
    _XA_NAME,
    _XA_NET_ADDRESS,
    _XA_NULL,
    _XA_OWNER_OS,
    _XA_SPAN,
    _XA_TARGETS,
    _XA_TEXT,
    _XA_TIMESTAMP,
    _XA_USER,
    _XA_UTF8_STRING;


char *XmuGetAtomName
(
 Display *dpy,
 Atom atom
 );

Atom XmuInternAtom
(
 Display *dpy,
 AtomPtr atom_ptr
 );

void XmuInternStrings
(
 Display *dpy,
 String *names,
 Cardinal count,
 Atom *atoms_return
);

AtomPtr XmuMakeAtom
(
 const char *name
 );

char *XmuNameOfAtom
(
 AtomPtr atom_ptr
 );




void XmuCopyISOLatin1Lowered
(
 char *dst_return,
 const char *src
 );

void XmuCopyISOLatin1Uppered
(
 char *dst_return,
 const char *src
 );

int XmuCompareISOLatin1
(
 const char *first,
 const char *second
 );

void XmuNCopyISOLatin1Lowered
(
 char *dst_return,
 const char *src,
 int size
 );

void XmuNCopyISOLatin1Uppered
(
 char *dst_return,
 const char *src,
 int size
 );







struct _IO_FILE;



typedef struct _IO_FILE FILE;





typedef struct _IO_FILE __FILE;




typedef struct
{
  int __count;
  union
  {

    unsigned int __wch;



    char __wchb[4];
  } __value;
} __mbstate_t;
typedef struct
{
  __off_t __pos;
  __mbstate_t __state;
} _G_fpos_t;
typedef struct
{
  __off64_t __pos;
  __mbstate_t __state;
} _G_fpos64_t;
typedef __builtin_va_list __gnuc_va_list;
struct _IO_jump_t; struct _IO_FILE;
typedef void _IO_lock_t;





struct _IO_marker {
  struct _IO_marker *_next;
  struct _IO_FILE *_sbuf;



  int _pos;
};


enum __codecvt_result
{
  __codecvt_ok,
  __codecvt_partial,
  __codecvt_error,
  __codecvt_noconv
};
struct _IO_FILE {
  int _flags;




  char* _IO_read_ptr;
  char* _IO_read_end;
  char* _IO_read_base;
  char* _IO_write_base;
  char* _IO_write_ptr;
  char* _IO_write_end;
  char* _IO_buf_base;
  char* _IO_buf_end;

  char *_IO_save_base;
  char *_IO_backup_base;
  char *_IO_save_end;

  struct _IO_marker *_markers;

  struct _IO_FILE *_chain;

  int _fileno;



  int _flags2;

  __off_t _old_offset;



  unsigned short _cur_column;
  signed char _vtable_offset;
  char _shortbuf[1];



  _IO_lock_t *_lock;
  __off64_t _offset;
  void *__pad1;
  void *__pad2;
  void *__pad3;
  void *__pad4;
  size_t __pad5;

  int _mode;

  char _unused2[15 * sizeof (int) - 4 * sizeof (void *) - sizeof (size_t)];

};


typedef struct _IO_FILE _IO_FILE;


struct _IO_FILE_plus;

extern struct _IO_FILE_plus _IO_2_1_stdin_;
extern struct _IO_FILE_plus _IO_2_1_stdout_;
extern struct _IO_FILE_plus _IO_2_1_stderr_;
typedef __ssize_t __io_read_fn (void *__cookie, char *__buf, size_t __nbytes);







typedef __ssize_t __io_write_fn (void *__cookie, const char *__buf,
     size_t __n);







typedef int __io_seek_fn (void *__cookie, __off64_t *__pos, int __w);


typedef int __io_close_fn (void *__cookie);
extern int __underflow (_IO_FILE *);
extern int __uflow (_IO_FILE *);
extern int __overflow (_IO_FILE *, int);
extern int _IO_getc (_IO_FILE *__fp);
extern int _IO_putc (int __c, _IO_FILE *__fp);
extern int _IO_feof (_IO_FILE *__fp) __attribute__ ((__nothrow__ , __leaf__));
extern int _IO_ferror (_IO_FILE *__fp) __attribute__ ((__nothrow__ , __leaf__));

extern int _IO_peekc_locked (_IO_FILE *__fp);





extern void _IO_flockfile (_IO_FILE *) __attribute__ ((__nothrow__ , __leaf__));
extern void _IO_funlockfile (_IO_FILE *) __attribute__ ((__nothrow__ , __leaf__));
extern int _IO_ftrylockfile (_IO_FILE *) __attribute__ ((__nothrow__ , __leaf__));
extern int _IO_vfscanf (_IO_FILE * __restrict, const char * __restrict,
   __gnuc_va_list, int *__restrict);
extern int _IO_vfprintf (_IO_FILE *__restrict, const char *__restrict,
    __gnuc_va_list);
extern __ssize_t _IO_padn (_IO_FILE *, int, __ssize_t);
extern size_t _IO_sgetn (_IO_FILE *, void *, size_t);

extern __off64_t _IO_seekoff (_IO_FILE *, __off64_t, int, int);
extern __off64_t _IO_seekpos (_IO_FILE *, __off64_t, int);

extern void _IO_free_backup_area (_IO_FILE *) __attribute__ ((__nothrow__ , __leaf__));




typedef __gnuc_va_list va_list;


typedef _G_fpos_t fpos_t;







extern struct _IO_FILE *stdin;
extern struct _IO_FILE *stdout;
extern struct _IO_FILE *stderr;







extern int remove (const char *__filename) __attribute__ ((__nothrow__ , __leaf__));

extern int rename (const char *__old, const char *__new) __attribute__ ((__nothrow__ , __leaf__));




extern int renameat (int __oldfd, const char *__old, int __newfd,
       const char *__new) __attribute__ ((__nothrow__ , __leaf__));








extern FILE *tmpfile (void) ;
extern char *tmpnam (char *__s) __attribute__ ((__nothrow__ , __leaf__)) ;





extern char *tmpnam_r (char *__s) __attribute__ ((__nothrow__ , __leaf__)) ;
extern char *tempnam (const char *__dir, const char *__pfx)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) ;








extern int fclose (FILE *__stream);




extern int fflush (FILE *__stream);

extern int fflush_unlocked (FILE *__stream);






extern FILE *fopen (const char *__restrict __filename,
      const char *__restrict __modes) ;




extern FILE *freopen (const char *__restrict __filename,
        const char *__restrict __modes,
        FILE *__restrict __stream) ;

extern FILE *fdopen (int __fd, const char *__modes) __attribute__ ((__nothrow__ , __leaf__)) ;
extern FILE *fmemopen (void *__s, size_t __len, const char *__modes)
  __attribute__ ((__nothrow__ , __leaf__)) ;




extern FILE *open_memstream (char **__bufloc, size_t *__sizeloc) __attribute__ ((__nothrow__ , __leaf__)) ;






extern void setbuf (FILE *__restrict __stream, char *__restrict __buf) __attribute__ ((__nothrow__ , __leaf__));



extern int setvbuf (FILE *__restrict __stream, char *__restrict __buf,
      int __modes, size_t __n) __attribute__ ((__nothrow__ , __leaf__));





extern void setbuffer (FILE *__restrict __stream, char *__restrict __buf,
         size_t __size) __attribute__ ((__nothrow__ , __leaf__));


extern void setlinebuf (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));








extern int fprintf (FILE *__restrict __stream,
      const char *__restrict __format, ...);




extern int printf (const char *__restrict __format, ...);

extern int sprintf (char *__restrict __s,
      const char *__restrict __format, ...) __attribute__ ((__nothrow__));





extern int vfprintf (FILE *__restrict __s, const char *__restrict __format,
       __gnuc_va_list __arg);




extern int vprintf (const char *__restrict __format, __gnuc_va_list __arg);

extern int vsprintf (char *__restrict __s, const char *__restrict __format,
       __gnuc_va_list __arg) __attribute__ ((__nothrow__));





extern int snprintf (char *__restrict __s, size_t __maxlen,
       const char *__restrict __format, ...)
     __attribute__ ((__nothrow__)) __attribute__ ((__format__ (__printf__, 3, 4)));

extern int vsnprintf (char *__restrict __s, size_t __maxlen,
        const char *__restrict __format, __gnuc_va_list __arg)
     __attribute__ ((__nothrow__)) __attribute__ ((__format__ (__printf__, 3, 0)));

extern int vdprintf (int __fd, const char *__restrict __fmt,
       __gnuc_va_list __arg)
     __attribute__ ((__format__ (__printf__, 2, 0)));
extern int dprintf (int __fd, const char *__restrict __fmt, ...)
     __attribute__ ((__format__ (__printf__, 2, 3)));








extern int fscanf (FILE *__restrict __stream,
     const char *__restrict __format, ...) ;




extern int scanf (const char *__restrict __format, ...) ;

extern int sscanf (const char *__restrict __s,
     const char *__restrict __format, ...) __attribute__ ((__nothrow__ , __leaf__));
extern int fscanf (FILE *__restrict __stream, const char *__restrict __format, ...) __asm__ ("" "__isoc99_fscanf")

                               ;
extern int scanf (const char *__restrict __format, ...) __asm__ ("" "__isoc99_scanf")
                              ;
extern int sscanf (const char *__restrict __s, const char *__restrict __format, ...) __asm__ ("" "__isoc99_sscanf") __attribute__ ((__nothrow__ , __leaf__))

                      ;








extern int vfscanf (FILE *__restrict __s, const char *__restrict __format,
      __gnuc_va_list __arg)
     __attribute__ ((__format__ (__scanf__, 2, 0))) ;





extern int vscanf (const char *__restrict __format, __gnuc_va_list __arg)
     __attribute__ ((__format__ (__scanf__, 1, 0))) ;


extern int vsscanf (const char *__restrict __s,
      const char *__restrict __format, __gnuc_va_list __arg)
     __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__format__ (__scanf__, 2, 0)));
extern int vfscanf (FILE *__restrict __s, const char *__restrict __format, __gnuc_va_list __arg) __asm__ ("" "__isoc99_vfscanf")



     __attribute__ ((__format__ (__scanf__, 2, 0))) ;
extern int vscanf (const char *__restrict __format, __gnuc_va_list __arg) __asm__ ("" "__isoc99_vscanf")

     __attribute__ ((__format__ (__scanf__, 1, 0))) ;
extern int vsscanf (const char *__restrict __s, const char *__restrict __format, __gnuc_va_list __arg) __asm__ ("" "__isoc99_vsscanf") __attribute__ ((__nothrow__ , __leaf__))



     __attribute__ ((__format__ (__scanf__, 2, 0)));









extern int fgetc (FILE *__stream);
extern int getc (FILE *__stream);





extern int getchar (void);

extern int getc_unlocked (FILE *__stream);
extern int getchar_unlocked (void);
extern int fgetc_unlocked (FILE *__stream);











extern int fputc (int __c, FILE *__stream);
extern int putc (int __c, FILE *__stream);





extern int putchar (int __c);

extern int fputc_unlocked (int __c, FILE *__stream);







extern int putc_unlocked (int __c, FILE *__stream);
extern int putchar_unlocked (int __c);






extern int getw (FILE *__stream);


extern int putw (int __w, FILE *__stream);








extern char *fgets (char *__restrict __s, int __n, FILE *__restrict __stream)
     ;
extern char *gets (char *__s) __attribute__ ((__deprecated__));


extern __ssize_t __getdelim (char **__restrict __lineptr,
          size_t *__restrict __n, int __delimiter,
          FILE *__restrict __stream) ;
extern __ssize_t getdelim (char **__restrict __lineptr,
        size_t *__restrict __n, int __delimiter,
        FILE *__restrict __stream) ;







extern __ssize_t getline (char **__restrict __lineptr,
       size_t *__restrict __n,
       FILE *__restrict __stream) ;








extern int fputs (const char *__restrict __s, FILE *__restrict __stream);





extern int puts (const char *__s);






extern int ungetc (int __c, FILE *__stream);






extern size_t fread (void *__restrict __ptr, size_t __size,
       size_t __n, FILE *__restrict __stream) ;




extern size_t fwrite (const void *__restrict __ptr, size_t __size,
        size_t __n, FILE *__restrict __s);

extern size_t fread_unlocked (void *__restrict __ptr, size_t __size,
         size_t __n, FILE *__restrict __stream) ;
extern size_t fwrite_unlocked (const void *__restrict __ptr, size_t __size,
          size_t __n, FILE *__restrict __stream);








extern int fseek (FILE *__stream, long int __off, int __whence);




extern long int ftell (FILE *__stream) ;




extern void rewind (FILE *__stream);

extern int fseeko (FILE *__stream, __off_t __off, int __whence);




extern __off_t ftello (FILE *__stream) ;






extern int fgetpos (FILE *__restrict __stream, fpos_t *__restrict __pos);




extern int fsetpos (FILE *__stream, const fpos_t *__pos);



extern void clearerr (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));

extern int feof (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;

extern int ferror (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;




extern void clearerr_unlocked (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));
extern int feof_unlocked (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern int ferror_unlocked (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;








extern void perror (const char *__s);






extern int sys_nerr;
extern const char *const sys_errlist[];




extern int fileno (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;




extern int fileno_unlocked (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern FILE *popen (const char *__command, const char *__modes) ;





extern int pclose (FILE *__stream);





extern char *ctermid (char *__s) __attribute__ ((__nothrow__ , __leaf__));
extern void flockfile (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));



extern int ftrylockfile (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;


extern void funlockfile (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));







void XmuDrawRoundedRectangle
(
 Display *dpy,
 Drawable draw,
 GC gc,
 int x,
 int y,
 int w,
 int h,
 int ew,
 int eh
 );

void XmuFillRoundedRectangle
(
 Display *dpy,
 Drawable draw,
 GC gc,
 int x,
 int y,
 int w,
 int h,
 int ew,
 int eh
 );

void XmuDrawLogo
(
 Display *dpy,
 Drawable drawable,
 GC gcFore,
 GC gcBack,
 int x,
 int y,
 unsigned int width,
 unsigned int height
 );

Pixmap XmuCreatePixmapFromBitmap
(
 Display *dpy,
 Drawable d,
 Pixmap bitmap,
 unsigned int width,
 unsigned int height,
 unsigned int depth,
 unsigned long fore,
 unsigned long back
);

Pixmap XmuCreateStippledPixmap
(
 Screen *screen,
 Pixel fore,
 Pixel back,
 unsigned int depth
 );

void XmuReleaseStippledPixmap
(
 Screen *screen,
 Pixmap pixmap
 );

Pixmap XmuLocateBitmapFile
(
 Screen *screen,
 const char *name,
 char *srcname_return,
 int srcnamelen,
 int *width_return,
 int *height_return,
 int *xhot_return,
 int *yhot_return
 );

Pixmap XmuLocatePixmapFile
(
 Screen *screen,
 const char *name,
 unsigned long fore,
 unsigned long back,
 unsigned int depth,
 char *srcname_return,
 int srcnamelen,
 int *width_return,
 int *height_return,
 int *xhot_return,
 int *yhot_return
 );

int XmuReadBitmapData
(
 FILE *fstream,
 unsigned int *width_return,
 unsigned int *height_return,
 unsigned char **datap_return,
 int *xhot_return,
 int *yhot_return
);

int XmuReadBitmapDataFromFile
(
 const char *filename,
 unsigned int *width_return,
 unsigned int *height_return,
 unsigned char **datap_return,
 int *xhot_return,
 int *yhot_return
 );




int XmuPrintDefaultErrorMessage
(
 Display *dpy,
 XErrorEvent *event,
 FILE *fp
 );

int XmuSimpleErrorHandler
(
 Display *dpy,
 XErrorEvent *errorp
 );




Boolean XmuConvertStandardSelection
(
 Widget w,
 Time timev,
 Atom *selection,
 Atom *target,
 Atom *type_return,
 XPointer *value_return,
 unsigned long *length_return,
 int *format_return
 );






typedef struct _XmuSegment {
  int x1, x2;
  struct _XmuSegment *next;
} XmuSegment;

typedef struct _XmuScanline {
  int y;
  XmuSegment *segment;
  struct _XmuScanline *next;
} XmuScanline;

typedef struct _XmuArea {
  XmuScanline *scanline;
} XmuArea;
XmuArea *XmuNewArea(int, int, int, int);
XmuArea *XmuAreaDup(XmuArea*);
XmuArea *XmuAreaCopy(XmuArea*, XmuArea*);
XmuArea *XmuAreaNot(XmuArea*, int, int, int, int);
XmuArea *XmuAreaOrXor(XmuArea*, XmuArea*, int);
XmuArea *XmuAreaAnd(XmuArea*, XmuArea*);
int XmuValidArea(XmuArea*);
int XmuValidScanline(XmuScanline*);
int XmuScanlineEqu(XmuScanline*, XmuScanline*);
XmuSegment *XmuNewSegment(int, int);
void XmuDestroySegmentList(XmuSegment*);
XmuScanline *XmuScanlineCopy(XmuScanline*, XmuScanline*);
int XmuAppendSegment(XmuSegment*, XmuSegment*);
XmuScanline *XmuOptimizeScanline(XmuScanline*);
XmuScanline *XmuScanlineNot(XmuScanline *scanline, int, int);
XmuScanline *XmuScanlineOr(XmuScanline*, XmuScanline*);
XmuScanline *XmuScanlineAnd(XmuScanline*, XmuScanline*);
XmuScanline *XmuScanlineXor(XmuScanline*, XmuScanline*);
XmuScanline *XmuNewScanline(int, int, int);
void XmuDestroyScanlineList(XmuScanline*);
XmuArea *XmuOptimizeArea(XmuArea *area);


XmuScanline *XmuScanlineOrSegment(XmuScanline*, XmuSegment*);
XmuScanline *XmuScanlineAndSegment(XmuScanline*, XmuSegment*);
XmuScanline *XmuScanlineXorSegment(XmuScanline*, XmuSegment*);



int XmuSnprintf(char *str, int size, const char *fmt, ...)
    __attribute__((__format__(__printf__,3,4)));
struct _XawTextProperty {
    XrmQuark identifier, code;
    unsigned long mask;
    XFontStruct *font;
    XFontSet fontset;
    Pixel foreground, background;
    Pixmap foreground_pixmap, background_pixmap;
    XrmQuark xlfd;

    unsigned long xlfd_mask;
    XrmQuark foundry, family, weight, slant, setwidth, addstyle, pixel_size,
      point_size, res_x, res_y, spacing, avgwidth, registry, encoding;

    short underline_position, underline_thickness;
};

struct _XawTextPropertyList {
    XrmQuark identifier;
    Screen *screen;
    Colormap colormap;
    int depth;
    XawTextProperty **properties;
    Cardinal num_properties;
    XawTextPropertyList *next;
};

typedef struct _XawTextPaintStruct XawTextPaintStruct;
struct _XawTextPaintStruct {
    XawTextPaintStruct *next;
    int x, y, width;
    char *text;
    Cardinal length;
    XawTextProperty *property;
    int max_ascent, max_descent;
    XmuArea *backtabs;
    Boolean highlight;
};

typedef struct {
    XmuArea *clip, *hightabs;
    XawTextPaintStruct *paint, *bearings;
} XawTextPaintList;

typedef struct {
    XtPointer next_extension;
    XrmQuark record_type;
    long version;
    Cardinal record_size;
    int (*BeginPaint)(Widget);
    void (*PreparePaint)(Widget, int, int,
    XawTextPosition, XawTextPosition, int);
    void (*DoPaint)(Widget);
    int (*EndPaint)(Widget);
} TextSinkExtRec, *TextSinkExt;


typedef void (*_XawSinkDisplayTextProc)
     (Widget, int, int, XawTextPosition, XawTextPosition, int);

typedef void (*_XawSinkInsertCursorProc)
     (Widget, int, int, XawTextInsertState);

typedef void (*_XawSinkClearToBackgroundProc)
     (Widget, int, int, unsigned int, unsigned int);

typedef void (*_XawSinkFindPositionProc)
     (Widget, XawTextPosition, int, int, int, XawTextPosition*, int*, int*);

typedef void (*_XawSinkFindDistanceProc)
     (Widget, XawTextPosition, int, XawTextPosition, int*,
      XawTextPosition*, int*);

typedef void (*_XawSinkResolveProc)
     (Widget, XawTextPosition, int, int, XawTextPosition*);

typedef int (*_XawSinkMaxLinesProc)
     (Widget, unsigned int);

typedef int (*_XawSinkMaxHeightProc)
     (Widget, int);

typedef void (*_XawSinkSetTabsProc)
     (Widget, int, short*);

typedef void (*_XawSinkGetCursorBoundsProc)
     (Widget, XRectangle*);

typedef struct _TextSinkClassPart {
    _XawSinkDisplayTextProc DisplayText;
    _XawSinkInsertCursorProc InsertCursor;
    _XawSinkClearToBackgroundProc ClearToBackground;
    _XawSinkFindPositionProc FindPosition;
    _XawSinkFindDistanceProc FindDistance;
    _XawSinkResolveProc Resolve;
    _XawSinkMaxLinesProc MaxLines;
    _XawSinkMaxHeightProc MaxHeight;
    _XawSinkSetTabsProc SetTabs;
    _XawSinkGetCursorBoundsProc GetCursorBounds;

    TextSinkExt extension;

} TextSinkClassPart;


typedef struct _TextSinkClassRec {
    ObjectClassPart object_class;
    TextSinkClassPart text_sink_class;
} TextSinkClassRec;

extern TextSinkClassRec textSinkClassRec;


typedef struct {

    Pixel foreground;
    Pixel background;


    Position *tabs;
    short *char_tabs;
    int tab_count;



    Pixel cursor_color;
    XawTextPropertyList *properties;
    XawTextPaintList *paint;
    XtPointer pad[2];

} TextSinkPart;


typedef struct _TextSinkRec {
    ObjectPart object;
    TextSinkPart text_sink;
} TextSinkRec;



XawTextPropertyList *XawTextSinkConvertPropertyList
(
 String name,
 String spec,
 Screen *screen,
 Colormap Colormap,
 int depth
 );

XawTextProperty *XawTextSinkGetProperty
(
 Widget w,
 XrmQuark property
 );

XawTextProperty *XawTextSinkCopyProperty
(
 Widget w,
 XrmQuark property
 );

XawTextProperty *XawTextSinkAddProperty
(
 Widget w,
 XawTextProperty *property
 );

XawTextProperty *XawTextSinkCombineProperty
(
 Widget w,
 XawTextProperty *result_in_out,
 XawTextProperty *property,
 int override
 );

int XawTextSinkBeginPaint
(
 Widget w
 );

void XawTextSinkPreparePaint
(
 Widget w,
 int y,
 int line,
 XawTextPosition from,
 XawTextPosition to,
 int highlight
);

void XawTextSinkDoPaint
(
 Widget w
 );

int XawTextSinkEndPaint
(
 Widget w
 );



typedef struct _AsciiSinkClassPart {
    XtPointer extension;
} AsciiSinkClassPart;


typedef struct _AsciiSinkClassRec {
    ObjectClassPart object_class;
    TextSinkClassPart text_sink_class;
    AsciiSinkClassPart ascii_sink_class;
} AsciiSinkClassRec;

extern AsciiSinkClassRec asciiSinkClassRec;


typedef struct {

    XFontStruct *font;
    Boolean echo;
    Boolean display_nonprinting;


    GC normgc, invgc, xorgc;
    XawTextPosition cursor_position;
    XawTextInsertState laststate;
    short cursor_x, cursor_y;

    XtPointer pad[4];

} AsciiSinkPart;


typedef struct _AsciiSinkRec {
    ObjectPart object;
    TextSinkPart text_sink;
    AsciiSinkPart ascii_sink;
} AsciiSinkRec;
typedef struct _Piece {

    char *text;
    XawTextPosition used;

    struct _Piece *prev, *next;
} Piece;

typedef struct _AsciiSrcClassPart {
    XtPointer extension;
} AsciiSrcClassPart;


typedef struct _AsciiSrcClassRec {
    ObjectClassPart object_class;
    TextSrcClassPart text_src_class;
    AsciiSrcClassPart ascii_src_class;
} AsciiSrcClassRec;

extern AsciiSrcClassRec asciiSrcClassRec;


typedef struct _AsciiSrcPart {

    char *string;

    XawAsciiType type;
    XawTextPosition piece_size;
    Boolean data_compression;




    Boolean use_string_in_place;
    int ascii_length;






    Boolean is_tempfile;



    Boolean allocated_string;

    XawTextPosition length;
    Piece *first_piece;

    XtPointer pad[4];

} AsciiSrcPart;


typedef struct _AsciiSrcRec {
    ObjectPart object;
    TextSrcPart text_src;
    AsciiSrcPart ascii_src;
} AsciiSrcRec;
extern WidgetClass multiSrcObjectClass;

typedef struct _MultiSrcClassRec *MultiSrcObjectClass;
typedef struct _MultiSrcRec *MultiSrcObject;


void XawMultiSourceFreeString
(
 Widget w
 );

int _XawMultiSave
(
 Widget w
);

int _XawMultiSaveAsFile
(
 Widget w,
 const char *name
 );


typedef struct _AsciiTextClassRec *AsciiTextWidgetClass;
typedef struct _AsciiRec *AsciiWidget;

extern WidgetClass asciiTextWidgetClass;



typedef struct {
  XtPointer extension;
} AsciiClassPart;

typedef struct _AsciiTextClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    TextClassPart text_class;
    AsciiClassPart ascii_class;
} AsciiTextClassRec;

extern AsciiTextClassRec asciiTextClassRec;

typedef struct {
    int resource;

    XtPointer pad[4];

} AsciiPart;

typedef struct _AsciiRec {
    CorePart core;
    SimplePart simple;
    TextPart text;
    AsciiPart ascii;
} AsciiRec;
extern WidgetClass boxWidgetClass;

typedef struct _BoxClassRec *BoxWidgetClass;
typedef struct _BoxRec *BoxWidget;




typedef struct {
    XtPointer extension;
} BoxClassPart;


typedef struct _BoxClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    BoxClassPart box_class;
} BoxClassRec;

extern BoxClassRec boxClassRec;


typedef struct {

    Dimension h_space, v_space;
    XtOrientation orientation;


    Dimension preferred_width, preferred_height;
    Dimension last_query_width, last_query_height;
    XtGeometryMask last_query_mode;

    XawDisplayList *display_list;
    XtPointer pad[4];

} BoxPart;




typedef struct _BoxRec {
    CorePart core;
    CompositePart composite;
    BoxPart box;
} BoxRec;
extern WidgetClass labelWidgetClass;

typedef struct _LabelClassRec *LabelWidgetClass;
typedef struct _LabelRec *LabelWidget;
extern WidgetClass commandWidgetClass;

typedef struct _CommandClassRec *CommandWidgetClass;
typedef struct _CommandRec *CommandWidget;
typedef struct {
    XtPointer extension;
} LabelClassPart;


typedef struct _LabelClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    LabelClassPart label_class;
} LabelClassRec;

extern LabelClassRec labelClassRec;


typedef struct {

    Pixel foreground;
    XFontStruct *font;
    XFontSet fontset;
    char *label;
    XtJustify justify;
    Dimension internal_width;
    Dimension internal_height;
    Pixmap pixmap;
    Boolean resize;
    unsigned char encoding;
    Pixmap left_bitmap;


    GC normal_GC;
    GC gray_GC;
    Pixmap stipple;
    Position label_x;
    Position label_y;
    Dimension label_width;
    Dimension label_height;
    Dimension label_len;
    int lbm_y;
    unsigned int lbm_width, lbm_height;

    XtPointer pad[4];

} LabelPart;




typedef struct _LabelRec {
    CorePart core;
    SimplePart simple;
    LabelPart label;
} LabelRec;

typedef enum {
    HighlightNone,
    HighlightWhenUnset,


    HighlightAlways

} XtCommandHighlight;


typedef struct _CommandClass {
    XtPointer extension;
} CommandClassPart;


typedef struct _CommandClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    LabelClassPart label_class;
    CommandClassPart command_class;
} CommandClassRec;

extern CommandClassRec commandClassRec;


typedef struct {

    Dimension highlight_thickness;
    XtCallbackList callbacks;


    Pixmap gray_pixmap;
    GC normal_GC;
    GC inverse_GC;
    Boolean set;
    XtCommandHighlight highlighted;


    int shape_style;
    Dimension corner_round;


    XtPointer pad[4];

} CommandPart;


typedef struct _CommandRec {
    CorePart core;
    SimplePart simple;
    LabelPart label;
    CommandPart command;
} CommandRec;
typedef enum {
    XawChainTop,

    XawChainBottom,

    XawChainLeft,

    XawChainRight,

    XawRubber

} XawEdgeType;
typedef struct _FormClassRec *FormWidgetClass;
typedef struct _FormRec *FormWidget;

extern WidgetClass formWidgetClass;



void XawFormDoLayout
(
 Widget w,



 Boolean do_layout

 );


typedef struct _DialogClassRec *DialogWidgetClass;
typedef struct _DialogRec *DialogWidget;

extern WidgetClass dialogWidgetClass;



void XawDialogAddButton
(
 Widget dialog,
 const char *name,
 XtCallbackProc function,
 XtPointer client_data
 );

char *XawDialogGetValueString
(
 Widget w
);






typedef enum {
    LayoutPending,
    LayoutInProgress,
    LayoutDone
} LayoutState;




typedef struct {
    Boolean(*layout)(FormWidget, unsigned int, unsigned int, int);

    XtPointer extension;

} FormClassPart;

typedef struct _FormClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    ConstraintClassPart constraint_class;
    FormClassPart form_class;
} FormClassRec;

extern FormClassRec formClassRec;

typedef struct _FormPart {

    int default_spacing;


    Dimension old_width, old_height;
    int no_refigure;
    Boolean needs_relayout;
    Boolean resize_in_layout;
    Dimension preferred_width, preferred_height;
    Boolean resize_is_no_op;

    XawDisplayList *display_list;
    XtPointer pad[4];

} FormPart;

typedef struct _FormRec {
    CorePart core;
    CompositePart composite;
    ConstraintPart constraint;
    FormPart form;
} FormRec;

typedef struct _FormConstraintsPart {

    XawEdgeType top, bottom, left, right;
    int dx;
    int dy;
    Widget horiz_base;
    Widget vert_base;
    Boolean allow_resize;


    short virtual_width, virtual_height;
    Position new_x, new_y;
    LayoutState layout_state;
    Boolean deferred_resize;

    short virtual_x, virtual_y;
    XtPointer pad[2];



} FormConstraintsPart;

typedef struct _FormConstraintsRec {
    FormConstraintsPart form;
} FormConstraintsRec, *FormConstraints;



typedef struct {
    XtPointer extension;
} DialogClassPart;

typedef struct _DialogClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    ConstraintClassPart constraint_class;
    FormClassPart form_class;
    DialogClassPart dialog_class;
} DialogClassRec;

extern DialogClassRec dialogClassRec;

typedef struct _DialogPart {

    String label;
    String value;
    Pixmap icon;


    Widget iconW;
    Widget labelW;
    Widget valueW;

    XtPointer pad[4];

} DialogPart;

typedef struct _DialogRec {
    CorePart core;
    CompositePart composite;
    ConstraintPart constraint;
    FormPart form;
    DialogPart dialog;
} DialogRec;

typedef struct {
    XtPointer extension;
} DialogConstraintsPart;

typedef struct _DialogConstraintsRec {
    FormConstraintsPart form;
    DialogConstraintsPart dialog;
} DialogConstraintsRec, *DialogConstraints;
typedef struct _XawGripCallData {
    XEvent *event;
    String *params;
    Cardinal num_params;
} XawGripCallDataRec, *XawGripCallData,
  GripCallDataRec, *GripCallData;



extern WidgetClass gripWidgetClass;

typedef struct _GripClassRec *GripWidgetClass;
typedef struct _GripRec *GripWidget;





typedef struct {
    XtPointer extension;
} GripClassPart;


typedef struct _GripClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    GripClassPart grip_class;
} GripClassRec;

extern GripClassRec gripClassRec;


typedef struct {
    XtCallbackList grip_action;

    XtPointer pad[4];

} GripPart;


typedef struct _GripRec {
    CorePart core;
    SimplePart simple;
    GripPart grip;
} GripRec;
extern WidgetClass listWidgetClass;

typedef struct _ListClassRec *ListWidgetClass;
typedef struct _ListRec *ListWidget;


typedef struct _XawListReturnStruct {
  String string;
  int list_index;
} XawListReturnStruct;


void XawListChange
(
 Widget w,
 String *list,
 int nitems,
 int longest,



 Boolean resize

 );
void XawListUnhighlight
(
 Widget w
 );
void XawListHighlight
(
 Widget w,
 int item
 );
XawListReturnStruct *XawListShowCurrent
(
 Widget w
 );








typedef struct {
    XtPointer extension;
} ListClassPart;


typedef struct _ListClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    ListClassPart list_class;
} ListClassRec;

extern ListClassRec listClassRec;


typedef struct {

    Pixel foreground;
    Dimension internal_width;
    Dimension internal_height;
    Dimension column_space;

    Dimension row_space;

    int default_cols;
    Boolean force_cols;
    Boolean paste;
    Boolean vertical_cols;
    int longest;
    int nitems;
    XFontStruct *font;
    XFontSet fontset;
    String *list;

    XtCallbackList callback;


    int is_highlighted;

    int highlight;

    int col_width;
    int row_height;
    int nrows;
    int ncols;
    GC normgc;
    GC revgc;
    GC graygc;
    int freedoms;


    int selected;
    Boolean show_current;
    char pad1[(sizeof(XtPointer) - sizeof(Boolean)) +
   (sizeof(XtPointer) - sizeof(int))];
    XtPointer pad2[2];

} ListPart;



typedef struct _ListRec {
    CorePart core;
    SimplePart simple;
    ListPart list;
} ListRec;
extern WidgetClass menuButtonWidgetClass;

typedef struct _MenuButtonClassRec *MenuButtonWidgetClass;
typedef struct _MenuButtonRec *MenuButtonWidget;


typedef struct _MenuButtonClass {
    XtPointer extension;
} MenuButtonClassPart;


typedef struct _MenuButtonClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    LabelClassPart label_class;
    CommandClassPart command_class;
    MenuButtonClassPart menuButton_class;
} MenuButtonClassRec;

extern MenuButtonClassRec menuButtonClassRec;


typedef struct {

    String menu_name;

    XtPointer pad[4];

} MenuButtonPart;


typedef struct _MenuButtonRec {
    CorePart core;
    SimplePart simple;
    LabelPart label;
    CommandPart command;
    MenuButtonPart menu_button;
} MenuButtonRec;
extern WidgetClass multiSinkObjectClass;

typedef struct _MultiSinkClassRec *MultiSinkObjectClass;
typedef struct _MultiSinkRec *MultiSinkObject;


typedef struct _MultiSinkClassPart {
    XtPointer extension;
} MultiSinkClassPart;


typedef struct _MultiSinkClassRec {
    ObjectClassPart object_class;
    TextSinkClassPart text_sink_class;
    MultiSinkClassPart multi_sink_class;
} MultiSinkClassRec;

extern MultiSinkClassRec multiSinkClassRec;


typedef struct {

    Boolean echo;
    Boolean display_nonprinting;


    GC normgc, invgc, xorgc;
    XawTextPosition cursor_position;
    XawTextInsertState laststate;
    short cursor_x, cursor_y;
    XFontSet fontset;

    XtPointer pad[4];

} MultiSinkPart;


typedef struct _MultiSinkRec {
    ObjectPart object;
    TextSinkPart text_sink;
    MultiSinkPart multi_sink;
} MultiSinkRec;







void _XawMultiSinkPosToXY
(
 Widget w,
 XawTextPosition pos,
 Position *x,
 Position *y
);


typedef struct _MultiPiece {

    wchar_t* text;
    XawTextPosition used;

    struct _MultiPiece *prev, *next;
} MultiPiece;


typedef struct _MultiSrcClassPart {
    XtPointer extension;
} MultiSrcClassPart;


typedef struct _MultiSrcClassRec {
    ObjectClassPart object_class;
    TextSrcClassPart text_src_class;
    MultiSrcClassPart multi_src_class;
} MultiSrcClassRec;

extern MultiSrcClassRec multiSrcClassRec;


typedef struct _MultiSrcPart {

    XIC ic;
    XtPointer string;

    XawAsciiType type;
    XawTextPosition piece_size;
    Boolean data_compression;




    Boolean use_string_in_place;
    int multi_length;



    Boolean is_tempfile;



    Boolean allocated_string;

    XawTextPosition length;
    MultiPiece *first_piece;

    XtPointer pad[4];

} MultiSrcPart;


typedef struct _MultiSrcRec {
  ObjectPart object;
  TextSrcPart text_src;
  MultiSrcPart multi_src;
} MultiSrcRec;



void _XawMultiSourceFreeString
(
 Widget w
 );


extern WidgetClass panedWidgetClass;

typedef struct _PanedClassRec *PanedWidgetClass;
typedef struct _PanedRec *PanedWidget;






void XawPanedSetMinMax
(
 Widget w,
 int min,
 int max
 );
void XawPanedGetMinMax
(
 Widget w,
 int *min_return,
 int *max_return
 );
void XawPanedSetRefigureMode
(
 Widget w,



 Boolean mode

 );
int XawPanedGetNumSub
(
 Widget w
 );
void XawPanedAllowResize
(
 Widget w,



 Boolean allow_resize

 );




typedef struct _PanedClassPart {
    XtPointer extension;
} PanedClassPart;


typedef struct _PanedClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    ConstraintClassPart constraint_class;
    PanedClassPart paned_class;
} PanedClassRec;

extern PanedClassRec panedClassRec;


typedef struct _PanedConstraintsPart {

    Dimension min;
    Dimension max;
    Boolean allow_resize;
    Boolean show_grip;

    Boolean skip_adjust;

    int position;

    Dimension preferred_size;

    Boolean resize_to_pref;




    Position delta;
    Position olddelta;
    Boolean paned_adjusted_me;

    Dimension wp_size;
    int size;
    Widget grip;
} PanedConstraintsPart, *Pane;

typedef struct _PanedConstraintsRec {
    PanedConstraintsPart paned;
} PanedConstraintsRec, *PanedConstraints;




typedef struct _PaneStack {
    struct _PaneStack *next;
    Pane pane;
    int start_size;

} PaneStack;


typedef struct {

    Position grip_indent;

    Boolean refiguremode;

    XtTranslations grip_translations;
    Pixel internal_bp;
    Dimension internal_bw;
    XtOrientation orientation;

    Cursor cursor;
    Cursor grip_cursor;
    Cursor v_grip_cursor;
    Cursor h_grip_cursor;
    Cursor adjust_this_cursor;
    Cursor v_adjust_this_cursor;
    Cursor h_adjust_this_cursor;


    Cursor adjust_upper_cursor;
    Cursor adjust_lower_cursor;


    Cursor adjust_left_cursor;
    Cursor adjust_right_cursor;


    Boolean recursively_called;
    Boolean resize_children_to_pref;


    int start_loc;
    Widget whichadd;
    Widget whichsub;
    GC normgc;
    GC invgc;
    GC flipgc;
    int num_panes;
    PaneStack *stack;

    XtPointer pad[4];

} PanedPart;




typedef struct _PanedRec {
    CorePart core;
    CompositePart composite;
    ConstraintPart constraint;
    PanedPart paned;
} PanedRec;
typedef struct {
    unsigned int changed;
    Position slider_x, slider_y;
    Dimension slider_width, slider_height;
    Dimension canvas_width, canvas_height;
} XawPannerReport;
extern WidgetClass pannerWidgetClass;

typedef struct _PannerClassRec *PannerWidgetClass;
typedef struct _PannerRec *PannerWidget;



typedef struct {
    XtPointer extension;
} PannerClassPart;


typedef struct _PannerClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    PannerClassPart panner_class;
} PannerClassRec;


typedef struct {

    XtCallbackList report_callbacks;
    Boolean allow_off;
    Boolean resize_to_pref;
    Pixel foreground;
    Pixel shadow_color;
    Dimension shadow_thickness;
    Dimension default_scale;
    Dimension line_width;
    Dimension canvas_width;
    Dimension canvas_height;
    Position slider_x;
    Position slider_y;
    Dimension slider_width;
    Dimension slider_height;
    Dimension internal_border;
    String stipple_name;


    GC slider_gc;
    GC shadow_gc;
    GC xor_gc;
    double haspect, vaspect;
    Boolean rubber_band;
    struct {
 Boolean doing;
 Boolean showing;
 Position startx, starty;
 Position dx, dy;
 Position x, y;
    } tmp;
    Position knob_x, knob_y;
    Dimension knob_width, knob_height;
    Boolean shadow_valid;
    XRectangle shadow_rects[2];
    Position last_x, last_y;

    XtPointer pad[4];

} PannerPart;

typedef struct _PannerRec {
    CorePart core;
    SimplePart simple;
    PannerPart panner;
} PannerRec;
extern PannerClassRec pannerClassRec;
extern WidgetClass portholeWidgetClass;
typedef struct _PortholeClassRec *PortholeWidgetClass;
typedef struct _PortholeRec *PortholeWidget;


typedef struct {
    XtPointer extension;
} PortholeClassPart;


typedef struct _PortholeClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    PortholeClassPart porthole_class;
} PortholeClassRec;


typedef struct {

    XtCallbackList report_callbacks;

    XtPointer pad[4];

} PortholePart;

typedef struct _PortholeRec {
    CorePart core;
    CompositePart composite;
    PortholePart porthole;
} PortholeRec;

extern PortholeClassRec portholeClassRec;
extern WidgetClass repeaterWidgetClass;

typedef struct _RepeaterClassRec *RepeaterWidgetClass;
typedef struct _RepeaterRec *RepeaterWidget;


typedef struct {
    XtPointer extension;
} RepeaterClassPart;


typedef struct _RepeaterClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    LabelClassPart label_class;
    CommandClassPart command_class;
    RepeaterClassPart repeater_class;
} RepeaterClassRec;

typedef struct {

    int initial_delay;
    int repeat_delay;
    int minimum_delay;
    int decay;
    Boolean flash;
    XtCallbackList start_callbacks;
    XtCallbackList stop_callbacks;


    int next_delay;
    XtIntervalId timer;

    XtPointer pad[4];

} RepeaterPart;

typedef struct _RepeaterRec {
    CorePart core;
    SimplePart simple;
    LabelPart label;
    CommandPart command;
    RepeaterPart repeater;
} RepeaterRec;







extern RepeaterClassRec repeaterClassRec;
typedef struct _ScrollbarRec *ScrollbarWidget;
typedef struct _ScrollbarClassRec *ScrollbarWidgetClass;

extern WidgetClass scrollbarWidgetClass;



void XawScrollbarSetThumb
(
 Widget scrollbar,




 float top,
 float shown

 );




typedef struct {

    Pixel foreground;
    XtOrientation orientation;
    XtCallbackList scrollProc;
    XtCallbackList thumbProc;
    XtCallbackList jumpProc;
    Pixmap thumb;
    Cursor upCursor;
    Cursor downCursor;
    Cursor leftCursor;
    Cursor rightCursor;
    Cursor verCursor;
    Cursor horCursor;
    float top;
    float shown;
    Dimension length;
    Dimension thickness;
    Dimension min_thumb;


    Cursor inactiveCursor;
    char direction;
    GC gc;
    Position topLoc;
    Dimension shownLength;

    XtPointer pad[4];

} ScrollbarPart;

typedef struct _ScrollbarRec {
    CorePart core;
    SimplePart simple;
    ScrollbarPart scrollbar;
} ScrollbarRec;

typedef struct {
  XtPointer extension;
} ScrollbarClassPart;

typedef struct _ScrollbarClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    ScrollbarClassPart scrollbar_class;
} ScrollbarClassRec;

extern ScrollbarClassRec scrollbarClassRec;
typedef struct _SimpleMenuClassRec* SimpleMenuWidgetClass;
typedef struct _SimpleMenuRec* SimpleMenuWidget;

extern WidgetClass simpleMenuWidgetClass;

void XawSimpleMenuAddGlobalActions
(
 XtAppContext app_con
 );
Widget XawSimpleMenuGetActiveEntry
(
 Widget w
 );
void XawSimpleMenuClearActiveEntry
(
 Widget w
);


typedef struct _SmeClassRec *SmeObjectClass;
typedef struct _SmeRec *SmeObject;

extern WidgetClass smeObjectClass;




typedef struct _SmeClassPart {
    XtWidgetProc highlight;
    XtWidgetProc unhighlight;
    XtWidgetProc notify;
    XtPointer extension;
} SmeClassPart;


typedef struct _SmeClassRec {
    RectObjClassPart rect_class;
    SmeClassPart sme_class;
} SmeClassRec;

extern SmeClassRec smeClassRec;


typedef struct {

    XtCallbackList callbacks;
    Boolean international;

    XtPointer pad[4];

} SmePart;


typedef struct _SmeRec {
    ObjectPart object;
    RectObjPart rectangle;
    SmePart sme;
} SmeRec;








typedef struct {
    XtPointer extension;
} SimpleMenuClassPart;

typedef struct _SimpleMenuClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    ShellClassPart shell_class;
    OverrideShellClassPart override_shell_class;
    SimpleMenuClassPart simpleMenu_class;
} SimpleMenuClassRec;

extern SimpleMenuClassRec simpleMenuClassRec;

typedef struct _SimpleMenuPart {

    String label_string;
    SmeObject label;

    WidgetClass label_class;
    Dimension top_margin;
    Dimension bottom_margin;
    Dimension row_height;
    Cursor cursor;
    SmeObject popup_entry;

    Boolean menu_on_screen;
    int backing_store;


    Boolean recursive_set_values;
    Boolean menu_width;

    Boolean menu_height;
    SmeObject entry_set;


    Dimension left_margin;
    Dimension right_margin;
    XawDisplayList *display_list;
    Widget sub_menu;
    unsigned char state;
    XtPointer pad[4];

} SimpleMenuPart;

typedef struct _SimpleMenuRec {
    CorePart core;
    CompositePart composite;
    ShellPart shell;
    OverrideShellPart override;
    SimpleMenuPart simple_menu;
} SimpleMenuRec;
typedef struct _SmeBSBClassRec *SmeBSBObjectClass;
typedef struct _SmeBSBRec *SmeBSBObject;

extern WidgetClass smeBSBObjectClass;

typedef struct _SmeBSBClassPart {
    XtPointer extension;
} SmeBSBClassPart;


typedef struct _SmeBSBClassRec {
    RectObjClassPart rect_class;
    SmeClassPart sme_class;
    SmeBSBClassPart sme_bsb_class;
} SmeBSBClassRec;

extern SmeBSBClassRec smeBSBClassRec;


typedef struct {

    String label;
    int vert_space;


    Pixmap left_bitmap, right_bitmap;
    Dimension left_margin, right_margin;
    Pixel foreground;
    XFontStruct *font;
    XFontSet fontset;
    XtJustify justify;


    Boolean set_values_area_cleared;
    GC norm_gc;
    GC rev_gc;
    GC norm_gray_gc;
    GC invert_gc;
    Dimension left_bitmap_width;
    Dimension left_bitmap_height;
    Dimension right_bitmap_width;
    Dimension right_bitmap_height;



    String menu_name;
    XtPointer pad[4];

} SmeBSBPart;




typedef struct _SmeBSBRec {
    ObjectPart object;
    RectObjPart rectangle;
    SmePart sme;
    SmeBSBPart sme_bsb;
} SmeBSBRec;
typedef struct _SmeLineClassRec *SmeLineObjectClass;
typedef struct _SmeLineRec *SmeLineObject;

extern WidgetClass smeLineObjectClass;


typedef struct _SmeLineClassPart {
    XtPointer extension;
} SmeLineClassPart;


typedef struct _SmeLineClassRec {
    RectObjClassPart rect_class;
    SmeClassPart sme_class;
    SmeLineClassPart sme_line_class;
} SmeLineClassRec;

extern SmeLineClassRec smeLineClassRec;


typedef struct {

    Pixel foreground;
    Pixmap stipple;
    Dimension line_width;


    GC gc;

    XtPointer pad[4];

} SmeLinePart;


typedef struct _SmeLineRec {
    ObjectPart object;
    RectObjPart rectangle;
    SmePart sme;
    SmeLinePart sme_line;
} SmeLineRec;
typedef struct _StripChartRec *StripChartWidget;
typedef struct _StripChartClassRec *StripChartWidgetClass;

extern WidgetClass stripChartWidgetClass;
typedef struct {

    Pixel fgpixel;
    Pixel hipixel;
    GC fgGC;
    GC hiGC;


    int update;
    int scale;
    int min_scale;
    int interval;
    XPoint *points;
    double max_value;
    double valuedata[2048];
    XtIntervalId interval_id;
    XtCallbackList get_value;
    int jump_val;

    XtPointer pad[4];

} StripChartPart;


typedef struct _StripChartRec {
    CorePart core;
    SimplePart simple;
    StripChartPart strip_chart;
} StripChartRec;


typedef struct {
    XtPointer extension;
} StripChartClassPart;


typedef struct _StripChartClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    StripChartClassPart strip_chart_class;
} StripChartClassRec;

extern StripChartClassRec stripChartClassRec;
typedef struct _TemplateClassRec *TemplateWidgetClass;
typedef struct _TemplateRec *TemplateWidget;


extern WidgetClass templateWidgetClass;







typedef struct {
    XtPointer extension;
} TemplateClassPart;

typedef struct _TemplateClassRec {
    CoreClassPart core_class;
    TemplateClassPart template_class;
} TemplateClassRec;

extern TemplateClassRec templateClassRec;

typedef struct {
    char* resource;
    char *_private;
} TemplatePart;

typedef struct _TemplateRec {
    CorePart core;
    TemplatePart _template;

} TemplateRec;
typedef struct _TipClassRec *TipWidgetClass;
typedef struct _TipRec *TipWidget;

extern WidgetClass tipWidgetClass;
void XawTipEnable
(
 Widget w
 );
void XawTipDisable
(
 Widget w
 );



typedef struct {
    XtPointer extension;
} TipClassPart;

typedef struct _TipClassRec {
    CoreClassPart core_class;
    TipClassPart tip_class;
} TipClassRec;

extern TipClassRec tipClassRec;

typedef struct _TipPart {

    Pixel foreground;
    XFontStruct *font;
    XFontSet fontset;
    Dimension top_margin;
    Dimension bottom_margin;
    Dimension left_margin;
    Dimension right_margin;
    int backing_store;
    int timeout;
    XawDisplayList *display_list;


    GC gc;
    XtIntervalId timer;
    String label;
    Boolean international;
    unsigned char encoding;
    XtPointer pad[4];
} TipPart;

typedef struct _TipRec {
    CorePart core;
    TipPart tip;
} TipRec;
extern WidgetClass toggleWidgetClass;

typedef struct _ToggleClassRec *ToggleWidgetClass;
typedef struct _ToggleRec *ToggleWidget;






void XawToggleChangeRadioGroup
(
 Widget w,
 Widget radio_group
 );
XtPointer XawToggleGetCurrent
(
 Widget radio_group
 );
void XawToggleSetCurrent
(
 Widget radio_group,
 XtPointer radio_data
 );
void XawToggleUnsetCurrent
(
 Widget radio_group
 );









typedef struct _RadioGroup {
    struct _RadioGroup *prev, *next;
    Widget widget;
} RadioGroup;


typedef struct _ToggleClass {
    XtActionProc Set;
    XtActionProc Unset;
    XtPointer extension;
} ToggleClassPart;


typedef struct _ToggleClassRec {
    CoreClassPart core_class;
    SimpleClassPart simple_class;
    LabelClassPart label_class;
    CommandClassPart command_class;
    ToggleClassPart toggle_class;
} ToggleClassRec;

extern ToggleClassRec toggleClassRec;


typedef struct {

    Widget widget;
    XtPointer radio_data;


    RadioGroup *radio_group;

    XtPointer pad[4];

} TogglePart;


typedef struct _ToggleRec {
    CorePart core;
    SimplePart simple;
    LabelPart label;
    CommandPart command;
    TogglePart toggle;
} ToggleRec;
extern WidgetClass treeWidgetClass;

typedef struct _TreeClassRec *TreeWidgetClass;
typedef struct _TreeRec *TreeWidget;



void XawTreeForceLayout
(
 Widget tree
 );



typedef struct _TreeClassPart {
    XtPointer extension;
} TreeClassPart;

typedef struct _TreeClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    ConstraintClassPart constraint_class;
    TreeClassPart tree_class;
} TreeClassRec;

extern TreeClassRec treeClassRec;

typedef struct {

    Dimension hpad;
    Dimension vpad;
    Dimension line_width;
    Pixel foreground;
    XtGravity gravity;
    Boolean auto_reconfigure;

    GC gc;
    Widget tree_root;
    Dimension *largest;
    int n_largest;
    Dimension maxwidth, maxheight;

    XawDisplayList *display_list;
    XtPointer pad[4];

} TreePart;


typedef struct _TreeRec {
    CorePart core;
    CompositePart composite;
    ConstraintPart constraint;
    TreePart tree;
} TreeRec;





typedef struct _TreeConstraintsPart {

    Widget parent;
    GC gc;

    Widget *children;
    int n_children;
    int max_children;
    Dimension bbsubwidth, bbsubheight;
    Dimension bbwidth, bbheight;
    Position x, y;

    XtPointer pad[2];



} TreeConstraintsPart;

typedef struct _TreeConstraintsRec {
   TreeConstraintsPart tree;
} TreeConstraintsRec, *TreeConstraints;
typedef struct _XawImPart {
    XIM xim;
    XrmResourceList resources;
    Cardinal num_resources;
    Boolean open_im;
    Boolean initialized;
    Dimension area_height;
    String input_method;
    String preedit_type;
} XawImPart;

typedef struct _XawIcTablePart {
    Widget widget;
    XIC xic;
    XIMStyle input_style;
    unsigned long flg;
    unsigned long prev_flg;
    Boolean ic_focused;
    XFontSet font_set;
    Pixel foreground;
    Pixel background;
    Pixmap bg_pixmap;
    XawTextPosition cursor_position;
    unsigned long line_spacing;
    Boolean openic_error;
    struct _XawIcTablePart *next;
} XawIcTablePart, *XawIcTableList;

typedef struct _XawIcPart {
    XIMStyle input_style;
    Boolean shared_ic;
    XawIcTableList shared_ic_table;
    XawIcTableList current_ic_table;
    XawIcTableList ic_table;
} XawIcPart;

typedef struct _contextDataRec {
    Widget parent;
    Widget ve;
} contextDataRec;

typedef struct _contextErrDataRec {
    Widget widget;
    XIM xim;
} contextErrDataRec;

void _XawImResizeVendorShell
(
 Widget w
 );

Dimension _XawImGetShellHeight
(
 Widget w
);

void _XawImRealize
(
 Widget w
 );

void _XawImInitialize
(
 Widget w,
 Widget ext
 );

void _XawImReconnect
(
 Widget w
 );

void _XawImRegister
(
 Widget w
 );

void _XawImUnregister
(
 Widget w
 );

void _XawImSetValues
(
 Widget w,
 ArgList args,
 Cardinal num_args
 );

void _XawImSetFocusValues
(
 Widget w,
 ArgList args,
 Cardinal num_args
);

void _XawImUnsetFocus
(
 Widget w
 );

int _XawImWcLookupString
(
 Widget w,
 XKeyPressedEvent *event,
 wchar_t *buffer_return,
 int bytes_buffer,
 KeySym *keysym_return
 );

int _XawLookupString
(
 Widget w,
 XKeyEvent *event,
 char *buffer_return,
 int buffer_size,
 KeySym *keysym_return
 );

int _XawImGetImAreaHeight
(
 Widget w
 );

void _XawImCallVendorShellExtResize
(
 Widget w
 );

void _XawImDestroy
(
 Widget w,
 Widget ext
 );

typedef struct {
    XtPointer extension;
} XawVendorShellExtClassPart;

typedef struct _VendorShellExtClassRec {
    ObjectClassPart object_class;
    XawVendorShellExtClassPart vendor_shell_ext_class;
} XawVendorShellExtClassRec;

typedef struct {
    Widget parent;
    XawImPart im;
    XawIcPart ic;

    XtPointer pad[4];

} XawVendorShellExtPart;

typedef struct XawVendorShellExtRec {
    ObjectPart object;
    XawVendorShellExtPart vendor_ext;
} XawVendorShellExtRec, *XawVendorShellExtWidget;
extern WidgetClass viewportWidgetClass;

typedef struct _ViewportClassRec *ViewportWidgetClass;
typedef struct _ViewportRec *ViewportWidget;



void XawViewportSetLocation
(
 Widget gw,




 float xoff,
 float yoff

 );

void XawViewportSetCoordinates
(
 Widget gw,




 Position x,
 Position y

 );




typedef struct {
    XtPointer extension;
} ViewportClassPart;

typedef struct _ViewportClassRec {
    CoreClassPart core_class;
    CompositeClassPart composite_class;
    ConstraintClassPart constraint_class;
    FormClassPart form_class;
    ViewportClassPart viewport_class;
} ViewportClassRec;

extern ViewportClassRec viewportClassRec;

typedef struct _ViewportPart {

    Boolean forcebars;

    Boolean allowhoriz;
    Boolean allowvert;
    Boolean usebottom;
    Boolean useright;
    XtCallbackList report_callbacks;


    Widget clip, child;
    Widget horiz_bar, vert_bar;

    XtPointer pad[4];

} ViewportPart;

typedef struct _ViewportRec {
    CorePart core;
    CompositePart composite;
    ConstraintPart constraint;
    FormPart form;
    ViewportPart viewport;
} ViewportRec;

typedef struct {
    int reparented;
} ViewportConstraintsPart;

typedef struct _ViewportConstraintsRec {
    FormConstraintsPart form;
    ViewportConstraintsPart viewport;
} ViewportConstraintsRec, *ViewportConstraints;

typedef Cardinal (*XtOrderProc)(
    Widget
);
