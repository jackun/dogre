module ogre.bindings.mini_win32;

/// Mainly for ogre.rendersystem.windows.windoweventutilities

version(Windows)
{
    public import core.sys.windows.windows;
    pragma(lib, "user32");
    pragma(lib, "gdi32");
    
    /*
    template CPtr(T) {
        alias const(T)* CPtr;
    }
    
    alias void* HANDLE;

    version (Win64) {
        alias long INT_PTR, LONG_PTR;
        alias long* PINT_PTR, PLONG_PTR;
        alias ulong UINT_PTR, ULONG_PTR, HANDLE_PTR;
        alias ulong* PUINT_PTR, PULONG_PTR;
        alias int HALF_PTR;
        alias int* PHALF_PTR;
        alias uint UHALF_PTR;
        alias uint* PUHALF_PTR;
    } else {
        alias int INT_PTR, LONG_PTR;
        alias int* PINT_PTR, PLONG_PTR;
        alias uint UINT_PTR, ULONG_PTR, HANDLE_PTR;
        alias uint* PUINT_PTR, PULONG_PTR;
        alias short HALF_PTR;
        alias short* PHALF_PTR;
        alias ushort UHALF_PTR;
        alias ushort* PUHALF_PTR;
    }*/

    const void* NULL = null;
    alias ubyte       BYTE;
    alias ubyte*      PBYTE, LPBYTE;
    alias ushort      USHORT, WORD, ATOM;
    alias ushort*     PUSHORT, PWORD, LPWORD;
    alias uint        ULONG, DWORD, UINT, COLORREF;
    alias uint*       PULONG, PDWORD, LPDWORD, PUINT, LPUINT;
    alias int         WINBOOL, BOOL, INT, LONG, HFILE, HRESULT;
    alias int*        PWINBOOL, LPWINBOOL, PBOOL, LPBOOL, PINT, LPINT, LPLONG;
    alias float       FLOAT;
    alias float*      PFLOAT;
    alias RECT*       LPCRECT; //whatever
    //Probably wrong
    alias char        TCHAR;

    /*alias CPtr!(void) PCVOID, LPCVOID;
    
    alias UINT_PTR WPARAM;
    alias LONG_PTR LPARAM, LRESULT;
    
    alias HANDLE HGLOBAL, HLOCAL, GLOBALHANDLE, LOCALHANDLE, HGDIOBJ, HACCEL,
        HBITMAP, HBRUSH, HCOLORSPACE, HDC, HGLRC, HDESK, HENHMETAFILE, HFONT,
            HICON, HINSTANCE, HKEY, HMENU, HMETAFILE, HMODULE, HMONITOR, HPALETTE, HPEN,
            HRGN, HRSRC, HSTR, HTASK, HWND, HWINSTA, HKL, HCURSOR;
    alias HANDLE* PHKEY;

    //winnt.d
    alias void   VOID;
    alias char   CHAR, CCHAR;
    alias wchar  WCHAR;
    alias bool   BOOLEAN;
    alias byte   FCHAR;
    alias ubyte  UCHAR;
    alias short  SHORT;
    alias ushort LANGID, FSHORT;
    alias uint   LCID, FLONG, ACCESS_MASK;
    alias long   LONGLONG, USN;
    alias ulong  DWORDLONG, ULONGLONG;
    
    alias void*  PVOID, LPVOID;
    alias char*  PSZ, PCHAR, PCCHAR, LPCH, PCH, LPSTR, PSTR;
    alias wchar* PWCHAR, LPWCH, PWCH, LPWSTR, PWSTR;
    alias bool*  PBOOLEAN;
    alias ubyte* PUCHAR;
    alias short* PSHORT;
    alias int*   PLONG;
    alias uint*  PLCID, PACCESS_MASK;
    alias long*  PLONGLONG;
    alias ulong* PDWORDLONG, PULONGLONG;
    
    // FIXME(MinGW) for __WIN64
    alias void*  PVOID64;
    
    // const versions
    alias CPtr!(char)  LPCCH, PCSTR, LPCSTR;
    alias CPtr!(wchar) LPCWCH, PCWCH, LPCWSTR, PCWSTR;
    
    version (Unicode) {
        alias WCHAR TCHAR, _TCHAR;
    } else {
        alias CHAR TCHAR, _TCHAR;
    }
    
    alias TCHAR        TBYTE;
    alias TCHAR*       PTCH, PTBYTE, LPTCH, PTSTR, LPTSTR, LP, PTCHAR;
    alias CPtr!(TCHAR) LPCTSTR;
    */

    /*ushort LOWORD(ulong l) {
        return cast(ushort) l;
    }
    
    ushort HIWORD(ulong l) {
        return cast(ushort) (l >>> 16);
    }*/
    
    ubyte LOBYTE(ushort w) {
        return cast(ubyte) w;
    }
    
    ubyte HIBYTE(ushort w) {
        return cast(ubyte) (w >>> 8);
    }

    struct POINT {
        LONG x;
        LONG y;
    }
    alias POINT POINTL;
    alias POINT* PPOINT, LPPOINT, PPOINTL, LPPOINTL;
    
    struct SIZE {
        LONG cx;
        LONG cy;
    }
    alias SIZE SIZEL;
    alias SIZE* PSIZE, LPSIZE, PSIZEL, LPSIZEL;
    
    struct POINTS {
        SHORT x;
        SHORT y;
    }
    alias POINTS* PPOINTS, LPPOINTS;
    
    /*enum : BOOL {
        FALSE = 0,
        TRUE  = 1
    }*/

    struct MINMAXINFO {
        POINT ptReserved;
        POINT ptMaxSize;
        POINT ptMaxPosition;
        POINT ptMinTrackSize;
        POINT ptMaxTrackSize;
    }
    alias MINMAXINFO* PMINMAXINFO, LPMINMAXINFO;

    /*struct MSG {
        HWND   hwnd;
        UINT   message;
        WPARAM wParam;
        LPARAM lParam;
        DWORD  time;
        POINT  pt;
    }
    alias MSG* LPMSG, PMSG;*/

    struct CREATESTRUCTA {
        LPVOID    lpCreateParams;
        HINSTANCE hInstance;
        HMENU     hMenu;
        HWND      hwndParent;
        int       cy;
        int       cx;
        int       y;
        int       x;
        LONG      style;
        LPCSTR    lpszName;
        LPCSTR    lpszClass;
        DWORD     dwExStyle;
    }
    alias CREATESTRUCTA* LPCREATESTRUCTA;
    
    struct CREATESTRUCTW {
        LPVOID    lpCreateParams;
        HINSTANCE hInstance;
        HMENU     hMenu;
        HWND      hwndParent;
        int       cy;
        int       cx;
        int       y;
        int       x;
        LONG      style;
        LPCWSTR   lpszName;
        LPCWSTR   lpszClass;
        DWORD     dwExStyle;
    }
    alias CREATESTRUCTW* LPCREATESTRUCTW;

    extern (Windows)
    {
        //BOOL PeekMessageA(LPMSG, HWND, UINT, UINT, UINT);
        //BOOL PeekMessageW(LPMSG, HWND, UINT, UINT, UINT);
        //BOOL TranslateMessage( CPtr!(MSG));
        //LONG DispatchMessageA( CPtr!(MSG));
        //LONG DispatchMessageW( CPtr!(MSG));
        LRESULT DefWindowProcA(HWND, UINT, WPARAM, LPARAM);
        LRESULT DefWindowProcW(HWND, UINT, WPARAM, LPARAM);

        LONG SetWindowLongA(HWND, int, LONG);
        LONG SetWindowLongW(HWND, int, LONG);
        LONG GetWindowLongA(HWND, int);
        LONG GetWindowLongW(HWND, int);

        version (Win64) {
            LONG_PTR GetWindowLongPtrA(HWND, int);
            LONG_PTR GetWindowLongPtrW(HWND, int);
            LONG_PTR SetWindowLongPtrA(HWND, int, LONG_PTR);
            LONG_PTR SetWindowLongPtrW(HWND, int, LONG_PTR);
        } else {
            alias GetWindowLongA GetWindowLongPtrA;
            alias GetWindowLongW GetWindowLongPtrW;
            alias SetWindowLongA SetWindowLongPtrA;
            alias SetWindowLongW SetWindowLongPtrW;
        }
    }

    version(Unicode)
    {
        alias PeekMessageW PeekMessage;
        //alias DispatchMessageW DispatchMessage;
        alias DefWindowProcW DefWindowProc;
        alias LPCREATESTRUCTW LPCREATESTRUCT;
        alias CREATESTRUCTW CREATESTRUCT;
        alias GetWindowLongW GetWindowLong;
        alias SetWindowLongW SetWindowLong;
        alias GetWindowLongPtrW GetWindowLongPtr;
        alias SetWindowLongPtrW SetWindowLongPtr;
    }
    else
    {
        alias PeekMessageA PeekMessage;
        alias DispatchMessageA DispatchMessage;
        alias DefWindowProcA DefWindowProc;
        alias LPCREATESTRUCTA LPCREATESTRUCT;
        alias CREATESTRUCTA CREATESTRUCT;
        alias GetWindowLongA GetWindowLong;
        alias SetWindowLongA SetWindowLong;
        alias GetWindowLongPtrA GetWindowLongPtr;
        alias SetWindowLongPtrA SetWindowLongPtr;
    }


    const PM_NOREMOVE = 0;
    const PM_REMOVE = 1;
    const PM_NOYIELD = 2;

    const WA_INACTIVE=0;
    const WA_ACTIVE=1;
    const WA_CLICKACTIVE=2;

    const WM_CREATE=1;
    const WM_DESTROY=2;
    const WM_MOVE=3;
    const WM_SIZE=5;
    const WM_ACTIVATE=6;
    const WM_CLOSE=16;
    const WM_GETMINMAXINFO=36;
    const WM_DISPLAYCHANGE=126;
    const WM_SYSKEYDOWN=260;
    const WM_SYSKEYUP=261;
    const WM_SYSCHAR=262;
    const WM_ENTERSIZEMOVE=561;
    const WM_EXITSIZEMOVE=562;
    /*
    enum {
        VK_LBUTTON = 0x01,
        VK_RBUTTON = 0x02,
        VK_CANCEL = 0x03,
        VK_MBUTTON = 0x04,
        //static if (_WIN32_WINNT > =  0x500) {
        VK_XBUTTON1 = 0x05,
        VK_XBUTTON2 = 0x06,
        //}
        VK_BACK = 0x08,
        VK_TAB = 0x09,
        VK_CLEAR = 0x0C,
        VK_RETURN = 0x0D,
        VK_SHIFT = 0x10,
        VK_CONTROL = 0x11,
        VK_MENU = 0x12,
        VK_PAUSE = 0x13,
        VK_CAPITAL = 0x14,
        VK_KANA = 0x15,
        VK_HANGEUL = 0x15,
        VK_HANGUL = 0x15,
        VK_JUNJA = 0x17,
        VK_FINAL = 0x18,
        VK_HANJA = 0x19,
        VK_KANJI = 0x19,
        VK_ESCAPE = 0x1B,
        VK_CONVERT = 0x1C,
        VK_NONCONVERT = 0x1D,
        VK_ACCEPT = 0x1E,
        VK_MODECHANGE = 0x1F,
        VK_SPACE = 0x20,
        VK_PRIOR = 0x21,
        VK_NEXT = 0x22,
        VK_END = 0x23,
        VK_HOME = 0x24,
        VK_LEFT = 0x25,
        VK_UP = 0x26,
        VK_RIGHT = 0x27,
        VK_DOWN = 0x28,
        VK_SELECT = 0x29,
        VK_PRINT = 0x2A,
        VK_EXECUTE = 0x2B,
        VK_SNAPSHOT = 0x2C,
        VK_INSERT = 0x2D,
        VK_DELETE = 0x2E,
        VK_HELP = 0x2F,
        VK_LWIN = 0x5B,
        VK_RWIN = 0x5C,
        VK_APPS = 0x5D,
        VK_SLEEP = 0x5F,
        VK_NUMPAD0 = 0x60,
        VK_NUMPAD1 = 0x61,
        VK_NUMPAD2 = 0x62,
        VK_NUMPAD3 = 0x63,
        VK_NUMPAD4 = 0x64,
        VK_NUMPAD5 = 0x65,
        VK_NUMPAD6 = 0x66,
        VK_NUMPAD7 = 0x67,
        VK_NUMPAD8 = 0x68,
        VK_NUMPAD9 = 0x69,
        VK_MULTIPLY = 0x6A,
        VK_ADD = 0x6B,
        VK_SEPARATOR = 0x6C,
        VK_SUBTRACT = 0x6D,
        VK_DECIMAL = 0x6E,
        VK_DIVIDE = 0x6F,
        VK_F1 = 0x70,
        VK_F2 = 0x71,
        VK_F3 = 0x72,
        VK_F4 = 0x73,
        VK_F5 = 0x74,
        VK_F6 = 0x75,
        VK_F7 = 0x76,
        VK_F8 = 0x77,
        VK_F9 = 0x78,
        VK_F10 = 0x79,
        VK_F11 = 0x7A,
        VK_F12 = 0x7B,
        VK_F13 = 0x7C,
        VK_F14 = 0x7D,
        VK_F15 = 0x7E,
        VK_F16 = 0x7F,
        VK_F17 = 0x80,
        VK_F18 = 0x81,
        VK_F19 = 0x82,
        VK_F20 = 0x83,
        VK_F21 = 0x84,
        VK_F22 = 0x85,
        VK_F23 = 0x86,
        VK_F24 = 0x87,
        VK_NUMLOCK = 0x90,
        VK_SCROLL = 0x91,
        VK_LSHIFT = 0xA0,
        VK_RSHIFT = 0xA1,
        VK_LCONTROL = 0xA2,
        VK_RCONTROL = 0xA3,
        VK_LMENU = 0xA4,
        VK_RMENU = 0xA5,
        //static if (_WIN32_WINNT > =  0x500) {
        VK_BROWSER_BACK = 0xA6,
        VK_BROWSER_FORWARD = 0xA7,
        VK_BROWSER_REFRESH = 0xA8,
        VK_BROWSER_STOP = 0xA9,
        VK_BROWSER_SEARCH = 0xAA,
        VK_BROWSER_FAVORITES = 0xAB,
        VK_BROWSER_HOME = 0xAC,
        VK_VOLUME_MUTE = 0xAD,
        VK_VOLUME_DOWN = 0xAE,
        VK_VOLUME_UP = 0xAF,
        VK_MEDIA_NEXT_TRACK = 0xB0,
        VK_MEDIA_PREV_TRACK = 0xB1,
        VK_MEDIA_STOP = 0xB2,
        VK_MEDIA_PLAY_PAUSE = 0xB3,
        VK_LAUNCH_MAIL = 0xB4,
        VK_LAUNCH_MEDIA_SELECT = 0xB5,
        VK_LAUNCH_APP1 = 0xB6,
        VK_LAUNCH_APP2 = 0xB7,
        //}
        VK_OEM_1 = 0xBA,
        //static if (_WIN32_WINNT > =  0x500) {
        VK_OEM_PLUS = 0xBB,
        VK_OEM_COMMA = 0xBC,
        VK_OEM_MINUS = 0xBD,
        VK_OEM_PERIOD = 0xBE,
        //}
        VK_OEM_2 = 0xBF,
        VK_OEM_3 = 0xC0,
        VK_OEM_4 = 0xDB,
        VK_OEM_5 = 0xDC,
        VK_OEM_6 = 0xDD,
        VK_OEM_7 = 0xDE,
        VK_OEM_8 = 0xDF,
        //static if (_WIN32_WINNT > =  0x500) {
        VK_OEM_102 = 0xE2,
        //}
        VK_PROCESSKEY = 0xE5,
        //static if (_WIN32_WINNT > =  0x500) {
        VK_PACKET = 0xE7,
        //}
        VK_ATTN = 0xF6,
        VK_CRSEL = 0xF7,
        VK_EXSEL = 0xF8,
        VK_EREOF = 0xF9,
        VK_PLAY = 0xFA,
        VK_ZOOM = 0xFB,
        VK_NONAME = 0xFC,
        VK_PA1 = 0xFD,
        VK_OEM_CLEAR = 0xFE,
    }*/

    alias HANDLE HMONITOR;
    enum int CCHDEVICENAME = 32;
    enum int CCHFORMNAME = 32;
    enum int MONITOR_DEFAULTTOPRIMARY = 1;
    enum int MONITOR_DEFAULTTONEAREST = 2;

    struct MONITORINFO
    {
        DWORD cbSize;
        RECT  rcMonitor;
        RECT  rcWork;
        DWORD dwFlags;
    }
    alias MONITORINFO* LPMONITORINFO;

    struct MONITORINFOEX
    {
        DWORD cbSize;
        RECT  rcMonitor;
        RECT  rcWork;
        DWORD dwFlags;
        TCHAR[CCHDEVICENAME] szDevice;
    }
    alias MONITORINFOEX *LPMONITORINFOEX;

    struct DEVMODE
    {
        TCHAR[CCHDEVICENAME] dmDeviceName;
        WORD  dmSpecVersion;
        WORD  dmDriverVersion;
        WORD  dmSize;
        WORD  dmDriverExtra;
        DWORD dmFields;
        union orient_pos_union{
            struct S0{
                short dmOrientation;
                short dmPaperSize;
                short dmPaperLength;
                short dmPaperWidth;
                short dmScale;
                short dmCopies;
                short dmDefaultSource;
                short dmPrintQuality;
            }
            struct S1{
                POINTL dmPosition;
                DWORD  dmDisplayOrientation;
                DWORD  dmDisplayFixedOutput;
            }
            S0 s0;//TODO anonymous struct?
            S1 s1;
        }
        orient_pos_union dmOrientPos;//TODO
        short dmColor;
        short dmDuplex;
        short dmYResolution;
        short dmTTOption;
        short dmCollate;
        TCHAR[CCHFORMNAME] dmFormName;
        WORD  dmLogPixels;
        DWORD dmBitsPerPel;
        DWORD dmPelsWidth;
        DWORD dmPelsHeight;
        union _union{
            DWORD dmDisplayFlags;
            DWORD dmNup;
        }
        _union dmUnion;//TODO
        DWORD dmDisplayFrequency;
//#if (WINVER >= 0x0400)
        DWORD dmICMMethod;
        DWORD dmICMIntent;
        DWORD dmMediaType;
        DWORD dmDitherType;
        DWORD dmReserved1;
        DWORD dmReserved2;
//#if (WINVER >= 0x0500) || (_WIN32_WINNT >= 0x0400)
        DWORD dmPanningWidth;
        DWORD dmPanningHeight;
//#endif 
//#endif 
    } 
    alias DEVMODE* PDEVMODE;
    alias DEVMODE* LPDEVMODE;
    alias DEVMODE DEVMODEA;
    alias WNDCLASSA WNDCLASS;

    enum
    {
        DISP_CHANGE_SUCCESSFUL = 0,
        BITSPIXEL     = 12,

        CDS_UPDATEREGISTRY           = 0x00000001,
        CDS_TEST                     = 0x00000002,
        CDS_FULLSCREEN               = 0x00000004,
        CDS_GLOBAL                   = 0x00000008,
        CDS_SET_PRIMARY              = 0x00000010,
        CDS_VIDEOPARAMETERS          = 0x00000020,

        GWL_WNDPROC         = (-4),
        GWL_HINSTANCE       = (-6),
        GWL_HWNDPARENT      = (-8),
        GWL_STYLE           = (-16),
        GWL_EXSTYLE         = (-20),
        GWL_USERDATA        = (-21),
        GWL_ID              = (-12),
        GWLP_USERDATA       = -21,

        DM_BITSPERPEL           = 0x00040000,
        DM_PELSWIDTH            = 0x00080000,
        DM_PELSHEIGHT           = 0x00100000,
        DM_DISPLAYFREQUENCY     = 0x00400000,

        SWP_NOSIZE          = 0x0001,
        SWP_NOMOVE          = 0x0002,
        SWP_NOZORDER        = 0x0004,
        SWP_NOREDRAW        = 0x0008,
        SWP_NOACTIVATE      = 0x0010,
        SWP_FRAMECHANGED    = 0x0020,  /* The frame changed: send WM_NCCALCSIZE */
        SWP_SHOWWINDOW      = 0x0040,
        SWP_HIDEWINDOW      = 0x0080,
        SWP_NOCOPYBITS      = 0x0100,
        SWP_NOOWNERZORDER   = 0x0200,  /* Don't do owner Z ordering */
        SWP_NOSENDCHANGING  = 0x0400,  /* Don't send WM_WINDOWPOSCHANGING */
        SWP_DRAWFRAME       = SWP_FRAMECHANGED,

        SW_HIDE             = 0,
        SW_SHOWNORMAL       = 1,
        SW_NORMAL           = 1,
        SW_SHOWMINIMIZED    = 2,
        SW_SHOWMAXIMIZED    = 3,
        SW_MAXIMIZE         = 3,
        SW_SHOWNOACTIVATE   = 4,
        SW_SHOW             = 5,
        SW_MINIMIZE         = 6,
        SW_SHOWMINNOACTIVE  = 7,
        SW_SHOWNA           = 8,
        SW_RESTORE          = 9,
        SW_SHOWDEFAULT      = 10,
        SW_FORCEMINIMIZE    = 11,
        SW_MAX              = 11,

        HWND_TOP        = (cast(HWND)0),
        HWND_BOTTOM     = (cast(HWND)1),
        HWND_TOPMOST    = (cast(HWND)-1),
        HWND_NOTOPMOST  = (cast(HWND)-2),

        PFD_DOUBLEBUFFER                = 0x00000001,
        PFD_STEREO                      = 0x00000002,
        PFD_DRAW_TO_WINDOW              = 0x00000004,
        PFD_DRAW_TO_BITMAP              = 0x00000008,
        PFD_SUPPORT_GDI                 = 0x00000010,
        PFD_SUPPORT_OPENGL              = 0x00000020,
        PFD_GENERIC_FORMAT              = 0x00000040,
        PFD_NEED_PALETTE                = 0x00000080,
        PFD_NEED_SYSTEM_PALETTE         = 0x00000100,
        PFD_SWAP_EXCHANGE               = 0x00000200,
        PFD_SWAP_COPY                   = 0x00000400,
        PFD_SWAP_LAYER_BUFFERS          = 0x00000800,
        PFD_GENERIC_ACCELERATED         = 0x00001000,
        PFD_SUPPORT_DIRECTDRAW          = 0x00002000,
        PFD_DEPTH_DONTCARE              = 0x20000000,
        PFD_DOUBLBUFFER_DONTCARE        = 0x40000000,
        PFD_STEREO_DONTCARE             = 0x80000000,
        PFD_TYPE_RGBA                   = 0,
    }
    
    enum IDC_ARROW          = MAKEINTRESOURCEA(32512);
    enum IDI_APPLICATION    = MAKEINTRESOURCEA(32512);


    version(Unicode)
        alias GetModuleHandleW GetModuleHandle;
    else
        alias GetModuleHandleA GetModuleHandle;

    alias SetWindowTextA SetWindowText;
    alias SendMessageA SendMessage;
    alias FormatMessageA FormatMessage;
    alias MessageBoxA MessageBox;
    alias ChangeDisplaySettingsExA ChangeDisplaySettingsEx;
    alias LoadIconA LoadIcon;
    alias LoadCursorA LoadCursor;
    alias RegisterClassA RegisterClass;
	alias UnregisterClassA UnregisterClass;
    alias CreateWindowExA CreateWindowEx;
    alias ChangeDisplaySettingsExA ChangeDisplaySettingsEx;
    alias GetClassNameA GetClassName;
	alias GetMonitorInfoA GetMonitorInfo;
	alias EnumDisplaySettingsA EnumDisplaySettings;
	

    extern(Windows)
    {
        alias BOOL function(HMONITOR,HDC,LPRECT,LPARAM) MONITORENUMPROC;

        //Gdi32
        HDC GetDC(HWND);
        int ChoosePixelFormat(HDC,PIXELFORMATDESCRIPTOR*);
        BOOL SetPixelFormat(HDC,int,PIXELFORMATDESCRIPTOR*);
        int GetPixelFormat(HDC);
        int DescribePixelFormat(HDC,int,UINT,PIXELFORMATDESCRIPTOR*);
        BOOL SwapBuffers(HDC);

        //User32
        BOOL GetMonitorInfoA(HMONITOR,void*LPMONITORINFO);
        HMONITOR MonitorFromPoint(POINT,DWORD);
        HMONITOR MonitorFromWindow(HWND ,DWORD);
        BOOL EnumDisplayMonitors(HDC,LPCRECT,MONITORENUMPROC,LPARAM);
        BOOL EnumDisplaySettingsA(LPCTSTR lpszDeviceName,DWORD iModeNum,DEVMODE *lpDevMode);
        BOOL DestroyWindow(HWND hWnd);
        BOOL UnregisterClassA(LPCTSTR lpClassName,HINSTANCE hInstance);
        HWND CreateWindowExA(DWORD dwExStyle,LPCSTR lpClassName,LPCSTR lpWindowName,DWORD dwStyle,
                             int X,int Y,int nWidth,int nHeight,
                             HWND hWndParent = null,HMENU hMenu = null,HINSTANCE hInstance = null,LPVOID lpParam = null);
        LONG ChangeDisplaySettingsExA(LPCSTR lpszDeviceName,DEVMODEA* lpDevMode,HWND hwnd,DWORD dwflags,LPVOID lParam);
        BOOL IsIconic(HWND);
        BOOL SetWindowPos(HWND,HWND,int X,int Y,int cx,int cy, uint uFlags);
        BOOL AdjustWindowRect(LPRECT,DWORD,BOOL);
        BOOL SetRect(RECT* lprc,int xLeft,int yTop,int xRight,int yBottom);
        HWND GetActiveWindow();
        int  GetClassNameA(HWND,LPSTR,INT);

        BOOL EnableWindow(HWND hWnd, BOOL bEnable);
        BOOL MoveWindow(HWND hWnd,int X,int Y,int nWidth,int nHeight,BOOL bRepaint);
        BOOL SetWindowTextA(HWND hWnd,LPCTSTR lpString = null);
        int GetDeviceCaps(HDC hdc,int nIndex);

    }
}
