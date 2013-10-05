module ogre.general.windows.configdialog;

version(Windows)
{
    import core.sys.windows.windows;
    import ogre.rendersystem.rendersystem;
    import ogre.compat;
    import ogre.exception;
    import ogre.general.common;
    import ogre.general.root;
    import ogre.bindings.mini_win32;

    pragma(msg, __FILE__);
    pragma(msg, "***** Keep these defines in sync with resource.h");
    pragma(msg, "***** Compile resource file in OgreD\\ogre\\general\\windows");
    //Resource defines
    enum : uint {
        IDD_DLG_VIDEO                   = 101,
        IDD_DLG_CONFIG                  = 101,
        IDI_ICON1                       = 103,
        IDB_SPLASH                      = 106,
        IDD_DLG_ERROR                   = 107,
        IDI_OGREICON                    = 111,
        IDC_CBO_VIDEO                   = 1001,
        IDC_VIDEO_MODE                  = 1002,
        ID_LBL_RES                      = 1003,
        IDC_CBO_RESOLUTION              = 1004,
        IDC_CBO_VIDEOMODE               = 1004,
        IDC_COLOUR_DEPTH                = 1005,
        IDC_CBO_COLOUR_DEPTH            = 1006,
        IDC_CHK_FULLSCREEN              = 1007,
        IDC_CBO_RENDERSYSTEM            = 1009,
        IDC_OPTFRAME                    = 1010,
        IDC_CBO_OPTION                  = 1011,
        IDC_LST_OPTIONS                 = 1013,
        IDC_LBL_OPTION                  = 1014,
        IDC_ERRMSG                      = 1018,
        IDC_SELECT_VIDEO                = -1,
    }

    enum : uint 
    {
        CB_ADDSTRING   = 0x0143,
        CB_GETCURSEL   = 0x0147,
        CB_GETCOUNT    = 0x0146,
        CB_SETCURSEL   = 0x014E,
        CB_RESETCONTENT  = 0x014B,

        LB_ADDSTRING    = 0x0180,
        LB_RESETCONTENT = 0x0184,
        LB_SETCURSEL    = 0x0186,
        LB_GETCURSEL    = 0x0188,

        CBN_SELCHANGE       = 1,
        LBN_SELCHANGE       = 1,

    }

    /** \addtogroup Core
     *  @{
     */
    /** \addtogroup General
     *  @{
     */
    
    /** Defines the behaviour of an automatic renderer configuration dialog.
     @remarks
     OGRE comes with it's own renderer configuration dialog, which
     applications can use to easily allow the user to configure the
     settings appropriate to their machine. This class defines the
     interface to this standard dialog. Because dialogs are inherently
     tied to a particular platform's windowing system, there will be a
     different subclass for each platform.
     @author
     Steven J. Streeting
     */
    class ConfigDialog //: public UtilityAlloc
    {
        static ConfigDialog dlg;

    public:
        this()
        {
            mHInstance = GetModuleHandle( null );
            //mSelectedRenderSystem = null;
        }
        ~this() {}
        
        /** Displays the dialog.
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
        bool display()
        {
            // Display dialog
            // Don't return to caller until dialog dismissed
            int i;
            dlg = this;
            
            i = DialogBoxParamA(mHInstance, MAKEINTRESOURCEA(IDD_DLG_CONFIG), null, &DlgProc, 0);
            
            if (i == -1)
            {
                int winError = GetLastError();
                char[] errDesc;
                int ret;
                
                errDesc = new char[255];
                // Try windows errors first
                ret = FormatMessage(
                    FORMAT_MESSAGE_FROM_SYSTEM |
                    FORMAT_MESSAGE_IGNORE_INSERTS,
                    null,
                    winError,
                    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
                    cast(LPTSTR) errDesc.ptr,
                    255,
                    null
                    );
                
                throw new InternalError(std.conv.to!string(errDesc), "ConfigDialog.display");
            }
            if (i)
                return true;
            else
                return false;

            //assert(0);
        }
        
    protected:
        /** Callback to process window events */
        //version(Win64)
        //    static INT_PTR DlgProc(HWND hDlg, UINT iMsg, WPARAM wParam, LPARAM lParam)
        //else
        extern (System) nothrow static INT_PTR DlgProc(HWND hDlg, UINT iMsg, WPARAM wParam, LPARAM lParam)
        {
            try
            {
                HWND hwndDlgItem;
                static RenderSystemList lstRend;
                //RenderSystemList::const_iterator pRend;
                static ConfigOptionMap opts;
                string err;
                
                int i, sel, savedSel;
                
                switch (iMsg)
                {
                    
                    case WM_INITDIALOG:
                        // Load saved settings
                        dlg.mSelectedRenderSystem = Root.getSingleton().getRenderSystem();
                        // Get all render systems
                        lstRend = Root.getSingleton().getAvailableRenderers();
                        i = 0;
                        foreach (pRend; lstRend)
                        {
                            hwndDlgItem = GetDlgItem(hDlg, IDC_CBO_RENDERSYSTEM);
                            
                            SendMessage(hwndDlgItem, CB_ADDSTRING, 0,
                                        cast(LPARAM)CSTR(pRend.getName()));
                            
                            if (pRend == dlg.mSelectedRenderSystem)
                            {
                                // Select
                                SendMessage(hwndDlgItem, CB_SETCURSEL, cast(WPARAM)i, 0);
                                // Refresh Options
                                // Get options from render system
                                opts = pRend.getConfigOptions();
                                // Reset list box
                                hwndDlgItem = GetDlgItem(hDlg, IDC_LST_OPTIONS);
                                //SendMessage(hwndDlgItem, LB_RESETCONTENT, 0, 0);
                                // Iterate through options
                                string strLine;
                                foreach( k, pOpt; opts )
                                {
                                    strLine = pOpt.name ~ ": " ~ pOpt.currentValue;
                                    SendMessage(hwndDlgItem, LB_ADDSTRING, 0, cast(LPARAM)CSTR(strLine));
                                }
                            }

                            ++i;
                        }
                        
                        // Center myself
                        int x, y, screenWidth, screenHeight;
                        RECT rcDlg;
                        GetWindowRect(hDlg, &rcDlg);
                        screenWidth = GetSystemMetrics(SM_CXFULLSCREEN);
                        screenHeight = GetSystemMetrics(SM_CYFULLSCREEN);
                        
                        x = (screenWidth / 2) - ((rcDlg.right - rcDlg.left) / 2);
                        y = (screenHeight / 2) - ((rcDlg.bottom - rcDlg.top) / 2);
                        
                        MoveWindow(hDlg, x, y, (rcDlg.right - rcDlg.left),
                                   (rcDlg.bottom - rcDlg.top), TRUE);
                        
                        return TRUE;
                        
                    case WM_COMMAND:
                        switch (LOWORD(wParam))
                        {
                            case IDC_CBO_RENDERSYSTEM:
                                hwndDlgItem = GetDlgItem(hDlg, IDC_CBO_RENDERSYSTEM);
                                sel = SendMessage( hwndDlgItem, CB_GETCOUNT, 0, 0 );
                                
                                if (HIWORD(wParam) == CBN_SELCHANGE )
                                {
                                    // RenderSystem selected
                                    // Get selected index
                                    hwndDlgItem = GetDlgItem(hDlg, IDC_CBO_RENDERSYSTEM);
                                    sel = SendMessage(hwndDlgItem, CB_GETCURSEL,0,0);
                                    if (sel != -1)
                                    {
                                        // Get RenderSystem selected
                                        dlg.mSelectedRenderSystem = lstRend[sel];
                                        // refresh options
                                        // Get options from render system
                                        opts = lstRend[sel].getConfigOptions();
                                        // Reset list box
                                        hwndDlgItem = GetDlgItem(hDlg, IDC_LST_OPTIONS);
                                        SendMessage(hwndDlgItem, LB_RESETCONTENT, 0, 0);
                                        // Iterate through options
                                        string strLine;
                                        foreach (k, pOpt; opts)
                                        {
                                            strLine = pOpt.name ~ ": " ~ pOpt.currentValue;
                                            SendMessage(hwndDlgItem, LB_ADDSTRING, 0, cast(LPARAM)CSTR(strLine));
                                        }
                                    }                    
                                }
                                
                                return TRUE;
                                
                            case IDC_LST_OPTIONS:
                                if (HIWORD(wParam) == LBN_SELCHANGE)
                                {
                                    // Selection in list box of options changed
                                    // Update combo and label in edit section
                                    hwndDlgItem = GetDlgItem(hDlg, IDC_LST_OPTIONS);
                                    sel = SendMessage(hwndDlgItem, LB_GETCURSEL, 0, 0);
                                    if (sel != -1)
                                    {
                                        //FIXME weird loop, use keys when linking works again :/
                                        ConfigOption pOpt;
                                        i = 0;
                                        foreach(k,v; opts)
                                        {
                                            pOpt = v;
                                            if(i>=sel) break; //break before
                                            i++;
                                        }

                                        // Set label text
                                        hwndDlgItem = GetDlgItem(hDlg, IDC_LBL_OPTION);
                                        SetWindowText(hwndDlgItem, CSTR(pOpt.name));
                                        // Set combo options
                                        hwndDlgItem = GetDlgItem(hDlg, IDC_CBO_OPTION);
                                        SendMessage(hwndDlgItem, CB_RESETCONTENT, 0, 0);
                                        i = 0;
                                        foreach(v; pOpt.possibleValues)
                                        {
                                            SendMessage(hwndDlgItem, CB_ADDSTRING, 0, cast(LPARAM)CSTR(v));
                                            if (v == pOpt.currentValue)
                                                // Select current value
                                                SendMessage(hwndDlgItem, CB_SETCURSEL, cast(WPARAM)i, 0);
                                            ++i;
                                        }
                                        // Enable/disable combo depending on (not)immutable
                                        EnableWindow(hwndDlgItem, !(pOpt._immutable) ? TRUE : FALSE);
                                    }
                                }
                                
                                return TRUE;
                                
                            case IDC_CBO_OPTION:
                                if (HIWORD(wParam) == CBN_SELCHANGE)
                                {
                                    // Updated an option
                                    // Get option
                                    hwndDlgItem = GetDlgItem(hDlg, IDC_LST_OPTIONS);
                                    sel = SendMessage(hwndDlgItem, LB_GETCURSEL, 0, 0);
                                    savedSel = sel;
                                    //FIXME weird loop, use keys when linking works again :/
                                    ConfigOption pOpt;
                                    i = 0;
                                    foreach(k,v; opts)
                                    {
                                        pOpt = v;
                                        if(i>=sel) break;
                                        i++;
                                    }

                                    // Get selected value
                                    hwndDlgItem = GetDlgItem(hDlg, IDC_CBO_OPTION);
                                    sel = SendMessage(hwndDlgItem, CB_GETCURSEL, 0, 0);
                                    
                                    if (sel != -1)
                                    {
                                        string[] pPoss = pOpt.possibleValues;
                                        
                                        // Set option
                                        dlg.mSelectedRenderSystem.setConfigOption(
                                            pOpt.name, pPoss[sel]);
                                        // Re-retrieve options
                                        opts = dlg.mSelectedRenderSystem.getConfigOptions();
                                        
                                        // Reset options list box
                                        hwndDlgItem = GetDlgItem(hDlg, IDC_LST_OPTIONS);
                                        SendMessage(hwndDlgItem, LB_RESETCONTENT, 0, 0);
                                        // Iterate through options
                                        string strLine;
                                        foreach (pOpt; opts)
                                        {
                                            strLine = pOpt.name ~ ": " ~ pOpt.currentValue;
                                            SendMessage(hwndDlgItem, LB_ADDSTRING, 0, cast(LPARAM)CSTR(strLine));
                                        }
                                        // Select previously selected item
                                        SendMessage(hwndDlgItem, LB_SETCURSEL, savedSel, 0);
                                    }
                                    
                                }
                                return TRUE;
                                
                            case IDOK:
                                // Set render system
                                if (!dlg.mSelectedRenderSystem)
                                {
                                    //Literals have '\0' appended
                                    MessageBoxA(null, "Please choose a rendering system.".ptr, "OGRE".ptr, MB_OK | MB_ICONEXCLAMATION);
                                    return TRUE;
                                }
                                err = dlg.mSelectedRenderSystem.validateConfigOptions();
                                if (err.length > 0)
                                {
                                    // refresh options incase updated by validation
                                    // Get options from render system
                                    opts = dlg.mSelectedRenderSystem.getConfigOptions();
                                    // Reset list box
                                    hwndDlgItem = GetDlgItem(hDlg, IDC_LST_OPTIONS);
                                    SendMessage(hwndDlgItem, LB_RESETCONTENT, 0, 0);
                                    // Iterate through options

                                    string strLine;
                                    foreach (pOpt;opts)
                                    {
                                        strLine = pOpt.name ~ ": " ~ pOpt.currentValue;
                                        SendMessage(hwndDlgItem, LB_ADDSTRING, 0, cast(LPARAM)CSTR(strLine));
                                    }
                                    MessageBox(null, CSTR(err), "OGRE", MB_OK | MB_ICONEXCLAMATION);
                                    return TRUE;
                                }
                                
                                Root.getSingleton().setRenderSystem(dlg.mSelectedRenderSystem);
                                
                                EndDialog(hDlg, TRUE);
                                return TRUE;
                                
                            case IDCANCEL:
                                EndDialog(hDlg, FALSE);
                                return TRUE;
                            default:
                                break;
                        }
                    default:
                        break;
                }
            }
            catch(Exception e)
            {

            }
            return FALSE;
        }
        RenderSystem mSelectedRenderSystem;
        HINSTANCE mHInstance; // HInstance of application, for dialog
    }
    /** @} */
    /** @} */
    
}
