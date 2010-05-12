{*****************************************************************}
{ This is an abstract class useful for creating your own context  }
{ menu handler (so you can add your own menu items to the menu    }
{ you get when you right-click a file or folder).                 }
{                                                                 }
{ CustomContextMenu is freeware. Feel free to use and improve it. }
{ I would be pleased to hear what you think.                      }
{                                                                 }
{ Troels Jakobsen - delphiuser@get2net.dk                         }
{ Copyright (c) 2003                                              }
{*****************************************************************}

unit CustomContextMenu;

interface

uses
  Windows, Classes, ActiveX, ComObj, ShlObj;

type
  TCustomContextMenu = class(TComObject, IShellExtInit, IContextMenu)
  private
    FFileNames: TStringList;
    FFolderName: String;
    FExtendedMode: Boolean;
    FIdCmdFirstOffset: UINT;         // Value of idCmdFirst in QueryContextMenu
  protected
    // IShellExtInit methods
    function IShellExtInit.Initialize = SEIInitialize;  // To avoid compiler warning
    function SEIInitialize(pidlFolder: PItemIDList; lpdobj: IDataObject;
      hKeyProgID: HKEY): HResult; stdcall;
    // IContextMenu methods
    function QueryContextMenu(Menu: HMENU; indexMenu, idCmdFirst, idCmdLast,
      uFlags: UINT): HResult; stdcall;
    function InvokeCommand(var lpici: TCMInvokeCommandInfo): HResult; stdcall;
    function GetCommandString(idCmd, uFlags: UINT; pwReserved: PUINT;
      pszName: LPSTR; cchMax: UINT): HResult; stdcall;
  public
    property FileNames: TStringList read FFileNames;
    property FolderName: String read FFolderName;
    property ExtendedMode: Boolean read FExtendedMode;
    property IdCmdFirstOffset: UINT read FIdCmdFirstOffset;
    procedure Initialize; override;
    destructor Destroy; override;
    // Abstract methods
    function AddMenuItems(Menu: HMENU; MenuIndex, IdCmdFirst, IdCmdLast: UINT): UINT;
      virtual; abstract;
    function GetHelpText(IdCmdOffset: UINT): String; virtual; abstract;
    function GetVerb(IdCmdOffset: UINT): String; virtual; abstract;
    procedure ExecuteCommand(IdCmdOffset: UINT); virtual; abstract;
  end;

  TOwnerDrawContextMenu = class(TCustomContextMenu, IContextMenu2, IContextMenu3)
  protected
    function HandleMenuMsg(uMsg: UINT; wParam, lParam: Integer): HResult; stdcall;
    function HandleMenuMsg2(uMsg: UINT; wParam, lParam: Integer;
      var lpResult: Integer): HResult; stdcall;
  public
    // Abstract methods
    procedure MeasureMenuItem(IdCmd: UINT; var Width: UINT; var Height: UINT); virtual; abstract;
    procedure DrawMenuItem(Menu: HMENU; IdCmd: UINT; DC: HDC; Rect: TRect; State: TOwnerDrawState);
      virtual; abstract;
    // Non-abstract methods
    function GetStandardTextWidth(Text: String): Longint;
    function GetStandardMenuItemHeight: Longint;
  end;

procedure Initialize(ComClass: TComClass; ClassID: TGUID; ClassName: String);
procedure RegisterHandler(ClassID: TGUID; Path: String; Description: String);
procedure UnregisterHandler(ClassID: TGUID);
procedure RegisterFileType(ClassID: TGUID; FileType, Name: String);
procedure UnregisterFileType(ClassID: TGUID; FileType, Name: String);


implementation

uses
  SysUtils, ShellApi, ComServ, Registry, Messages;

{----------------- TCustomContextMenu -----------------}

procedure TCustomContextMenu.Initialize;
begin
  inherited;
  FFileNames := TStringList.Create;
end;


destructor TCustomContextMenu.Destroy;
begin
  FFileNames.Free;
  inherited;
end;


function TCustomContextMenu.SEIInitialize(pidlFolder: PItemIDList; lpdobj: IDataObject;
  hKeyProgID: HKEY): HResult;
{ This is the first method the shell calls after it creates an instance of a
  context menu extension (or a property sheet extension, or drag-and-drop handler). }
var
  StgMedium: TStgMedium;
  FormatEtc: TFormatEtc;
  Buffer: array[0..MAX_PATH] of Char;
  I: Integer;
  FileCount: Integer;
begin
  // Fail the call if lpdobj is Nil.
  if (lpdobj = nil) then
  begin
    Result := E_INVALIDARG;
    Exit;
  end;

  with FormatEtc do
  begin
    cfFormat := CF_HDROP;
    ptd      := nil;
    dwAspect := DVASPECT_CONTENT;
    lindex   := -1;
    tymed    := TYMED_HGLOBAL;
  end;

  // lpdobj points to a list of the selected objects in CF_HDROP format
  Result := lpdobj.GetData(FormatEtc, StgMedium);
  if Failed(Result) then
    Exit;

  FileCount := DragQueryFile(StgMedium.hGlobal, $FFFFFFFF, nil, 0);
  try
    if FileCount > 0 then
    begin
      for I := 0 to FileCount -1 do
      begin
        DragQueryFile(StgMedium.hGlobal, I, Buffer, MAX_PATH);
        FFileNames.Add(StrPas(Buffer));
      end;
      Result := NOERROR;
    end
    else
      Result := E_FAIL;
  except
    on E: Exception do
      Result := E_FAIL;
  end;
  ReleaseStgMedium(StgMedium);

  // Get path of current folder
  SHGetPathFromIDList(pidlFolder, Buffer);
  FFolderName := StrPas(Buffer);
  { As far as I can tell from the documentation on IShellExtInit.Initialize,
    pidlFolder is always NULL for context menu handlers. It supposedly contains the
    folder name for "folder background shortcut menus". Is this the context menu
    you get when you right-click on the background of a folder (the menu that allows
    you to arrange the content and create new items)? I think so, but I'm not sure.
    Please tell me if you know. And please tell me how to get to this background menu. }
  { Anyway, let's get the current folder's path. }
  if FFolderName = '' then
    if FFileNames.Count > 0 then
      FFolderName := ExtractFileDir(FFileNames[0]);
end;


function TCustomContextMenu.QueryContextMenu(Menu: HMENU; indexMenu, idCmdFirst,
  idCmdLast, uFlags: UINT): HResult;
var
  LastUserCmdId: UINT;
begin
  FIdCmdFirstOffset := IdCmdFirst;
  FExtendedMode := ((uFlags and $00000100) <> 0);
  LastUserCmdId := 0;
  if (uFlags <> CMF_NORMAL) and (uFlags <> CMF_DEFAULTONLY) and
     ((uFlags and $0000000F) = CMF_NORMAL) or ((uFlags and CMF_EXPLORE) <> 0) then
  begin
    { uFlags doesn't really contain any interesting information for context menu
      handlers, which is why I chose not to let it be a parameter in AddMenuItems. }
    LastUserCmdId := AddMenuItems(Menu, indexMenu, idCmdFirst, idCmdLast);
  end;
  if LastUserCmdId = 0 then
    Result := E_FAIL
  else
    Result := MakeResult(SEVERITY_SUCCESS, FACILITY_NULL, LastUserCmdId - idCmdFirst + 1);
end;


function TCustomContextMenu.InvokeCommand(var lpici: TCMInvokeCommandInfo): HResult;
var
  IdCmd: UINT;
begin
  { If the high-order word of lpici.lpVerb is not NULL, this function was called by
    an application and lpVerb is a command that should be activated. Otherwise, the
    shell has called this function (as is almost always the case), and the low-order
    word of lpici.lpVerb is the identifier of the menu item that the user selected. }
  { CustomContextMenu doesn't support menu items being called by anything but the shell. }
  { See http://msdn.microsoft.com/library/en-us/shellcc/platform/shell/reference/structures/cminvokecommandinfo.asp
    for help on the CMINVOKECOMMANDINFO structure. }

  Result := E_FAIL;

  // Fail if we're being called by an application (instead of the shell)
  if (HiWord(Integer(lpici.lpVerb)) <> 0) then
    Exit;

  // Execute the command specified by lpici.lpVerb
  IdCmd := LoWord(UINT(lpici.lpVerb));
  ExecuteCommand(IdCmd);

  Result := NOERROR;         // S_OK
end;


function WideStringAsPChar(S: String): PChar;
{ Convert a string (ANSI) of limited length to a wide string (UNICODE) and return
  the result as a PChar. This method is rather crude, but it does the job.
  An alternative would be to use MultiByteToWideChar, but that gives us a PWideChar
  and we need a PChar. }
var
  I: Integer;
  WideStr: array[0..511] of Char;
begin
  FillChar(WideStr, SizeOf(WideStr), 0);
  for I := 0 to Length(S) -1 do
  begin
    if I = 254 then
      Break;
    WideStr[I*2] := S[I];
  end;
  Result := WideStr;
end;


function TCustomContextMenu.GetCommandString(idCmd, uFlags: UINT; pwReserved: PUINT;
  pszName: LPSTR; cchMax: UINT): HRESULT;
begin
  case uFlags of
    GCS_VERBA:
      StrLCopy(pszName, PChar(GetVerb(idCmd)), cchMax);
    GCS_HELPTEXTA:
      StrLCopy(pszName, PChar(GetHelpText(idCmd)), cchMax);
    GCS_VERBW:
      StrLCopy(pszName, WideStringAsPChar(GetVerb(idCmd)), cchMax);
    GCS_HELPTEXTW:
      StrLCopy(pszName, WideStringAsPChar(GetHelpText(idCmd)), cchMax);
  end;
  Result := NOERROR;
end;

{--------------- TOwnerDrawContextMenu ----------------}

function TOwnerDrawContextMenu.HandleMenuMsg(uMsg: UINT; wParam, lParam: Integer): HResult;
var
  mis: PMeasureItemStruct;
  dis: PDrawItemStruct;
 begin
  Result := NOERROR;

  case uMsg of
    WM_MEASUREITEM: begin
      try
        mis := PMeasureItemStruct(lParam);
        // Call abstract method
        MeasureMenuItem(mis.itemID, mis.itemWidth, mis.itemHeight);
      except
        Result := E_FAIL;
      end;
    end;

    WM_DRAWITEM: begin
      try
        dis := PDrawItemStruct(LParam);
        // Call abstract method
        DrawMenuItem(dis.hwndItem, dis.itemID, dis.hDC, dis.rcItem, TOwnerDrawState(LongRec(dis.itemState).Lo));
      except
        Result := E_FAIL;
      end;
    end;

  end;
end;


function TOwnerDrawContextMenu.HandleMenuMsg2(uMsg: UINT; wParam, lParam: Integer;
         var lpResult: Integer): HResult;
begin
  { According to the API documentation WM_MEASUREITEM and WM_DRAWITEM should be
    sent to the IContextMenu2 implementation, but they're actually sent to the
    IContextMenu3 implementation. Strange. But things work if we just pass the
    messages along from IContextMenu3.HandleMenuMsg2 to IContextMenu2.HandleMenuMsg. }
  Result := HandleMenuMsg(uMsg, wParam, lParam);
end;


function TOwnerDrawContextMenu.GetStandardTextWidth(Text: String): Longint;
{ This method calculates the width of some text using the default menu font.
  We create a DC manually and load the font used for menus into it. }
var
  Size: TSize;
  DC: HDC;
  ncm: TNonClientMetrics;
  HMenuFont: THandle;
  Width: LongWord;
begin
  Width := 0;
  DC := CreateCompatibleDC(0);
  try
    if DC <> 0 then
    begin
      ncm.cbSize := SizeOf(ncm);
      if SystemParametersInfo(SPI_GETNONCLIENTMETRICS, ncm.cbSize, @ncm, 0) then
        HMenuFont := CreateFontIndirect(ncm.lfMenuFont)
      else
        HMenuFont := GetStockObject(SYSTEM_FONT);
      SelectObject(DC, HMenuFont);
      if GetTextExtentPoint32(DC, PChar(Text), Length(Text), Size) then
        Width := Size.cx;
      DeleteObject(HMenuFont);
    end;
  finally
    DeleteDC(DC);
  end;
  Result := Width;
end;


function TOwnerDrawContextMenu.GetStandardMenuItemHeight: Longint;
begin
  Result := GetSystemMetrics(SM_CYMENU);
end;

{------------------- Initialization -------------------}

procedure Initialize(ComClass: TComClass; ClassID: TGUID; ClassName: String);
begin
  TComObjectFactory.Create(ComServer, ComClass, ClassID, ClassName, '', ciMultiInstance, tmApartment);
end;

{------ Registration methods (for external use) -------}

function WriteRegKey(Registry: TRegistry; Key, Name, Value: String): Boolean;
begin
  Result := False;
  if Registry.OpenKey(Key, True) then
  begin
    Registry.WriteString(Name, Value);
    Result := True;
  end;
  Registry.CloseKey;
end;


procedure RegisterHandler(ClassID: TGUID; Path: String; Description: String);
var
  StrClassID: String;
  CLSIDKey: String;
  Reg: TRegistry;
begin
  StrClassID := GUIDToString(ClassID);
  CLSIDKey := 'CLSID\' + StrClassID;
  Reg := TRegistry.Create;
  try
    // Set appropriate keys under HKCR\CLSID
    Reg.RootKey := HKEY_CLASSES_ROOT;
    WriteRegKey(Reg, CLSIDKey, '', Description);
    WriteRegKey(Reg, CLSIDKey + '\InprocServer32', '', Path);
    WriteRegKey(Reg, CLSIDKey + '\InprocServer32', 'ThreadingModel', 'Apartment');

    if (Win32Platform = VER_PLATFORM_WIN32_NT) then
    begin
      // Set appropriate keys under HKLM\software\...
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      Reg.OpenKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions', True);
//      Reg.OpenKey('Approved', True);
//      WriteString(StrClassID, Description);
      WriteRegKey(Reg, 'Approved', StrClassID, Description);
    end;
  finally
    Reg.Free;
  end;
end;


procedure UnregisterHandler(ClassID: TGUID);
var
  CLSIDKey: String;
  Reg: TRegistry;
begin
  CLSIDKey := 'CLSID\' + GUIDToString(ClassID);
  Reg := TRegistry.Create;
  try
    // Delete appropriate keys under HKCR\CLSID
    Reg.RootKey := HKEY_CLASSES_ROOT;
    Reg.DeleteKey(CLSIDKey + '\InprocServer32');
    Reg.DeleteKey(CLSIDKey);
  finally
    Reg.Free;
  end;
end;


procedure RegisterFileType(ClassID: TGUID; FileType, Name: String);
var
  StrClassID: String;
  Reg: TRegistry;
begin
  StrClassID := GUIDToString(ClassID);
  Reg := TRegistry.Create;
  try
    // Set appropriate keys under HKCR\(FileType)\shellex
    Reg.RootKey := HKEY_CLASSES_ROOT;
    WriteRegKey(Reg, FileType + '\shellex', '', '');
    WriteRegKey(Reg, FileType + '\shellex\ContextMenuHandlers', '', '');
    WriteRegKey(Reg, FileType + '\shellex\ContextMenuHandlers\' + Name, '', StrClassID);
  finally
    Reg.Free;
  end;
end;


procedure UnregisterFileType(ClassID: TGUID; FileType, Name: String);
var
  StrClassID: String;
  CLSIDKey: String;
  Reg: TRegistry;
  Keys: TStringList;
begin
  StrClassID := GUIDToString(ClassID);
  CLSIDKey := 'CLSID\' + StrClassID;
  Reg := TRegistry.Create;
  try
    with Reg do
    begin
      // Delete appropriate keys under HKCR\(FileType)\shellex
      RootKey := HKEY_CLASSES_ROOT;
      DeleteKey(FileType + '\shellex\ContextMenuHandlers\' + Name);
{$DEFINE REMOVE_EMPTY_KEYS}
{$IFDEF REMOVE_EMPTY_KEYS}
      // Delete parent keys if they're empty
      if OpenKey(FileType + '\shellex\ContextMenuHandlers', False) then
      begin
        Keys := TStringList.Create;
        GetKeyNames(Keys);
        try
          if Keys.Count = 0 then
          begin
            CloseKey;
            DeleteKey(FileType + '\shellex\ContextMenuHandlers');
            if OpenKey(FileType + '\shellex', False) then
            begin
              GetKeyNames(Keys);
              if Keys.Count = 0 then
              begin
                CloseKey;
                DeleteKey(FileType + '\shellex');
              end;
            end;
          end;
        finally
          Keys.Free;
        end;
      end;
      CloseKey;
{$ENDIF}
    end;
  finally
    Reg.Free;
  end;
end;

end.

