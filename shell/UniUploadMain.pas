unit UniUploadMain;

interface

uses
  Windows, CustomContextMenu, Graphics;

type
  TMyContextMenu = class(TCustomContextMenu)
  public
    BT: array of TBitmap;
    function GetHelpText(IdCmdOffset: UINT): String; override;
    function GetVerb(IdCmdOffset: UINT): String; override;
    function AddMenuItems(Menu: HMENU; MenuIndex, IdCmdFirst, IdCmdLast: UINT): UINT; override;
    procedure ExecuteCommand(IdCmdOffset: UINT); override;
    procedure RefreshServices;
  end;


implementation

uses
  SysUtils, Registry;

var 
  ServiceNames: array of string; //=('RapidShare','ImageShack','CyberShadow');
  ImageNames  : array of string; //=('UPLOAD'    ,'IMAGESHACK','CYBERSHADOW');
  
const
  AllowedImageShackExtensions='.jpeg|.jpg|.png|.gif|.bmp|.tif|.tiff|.swf';
  GUID_ContextMenuEntry: TGUID = '{B33DE756-DEEE-4D7A-87DB-900854B1D3A4}';

{------------------- TMyContextMenu -------------------}

function TMyContextMenu.GetHelpText(IdCmdOffset: UINT): String;
begin
  Result := 'Upload files to '+ServiceNames[IdCmdOffset];
end;


function TMyContextMenu.GetVerb(IdCmdOffset: UINT): String;
begin
  Result := 'upload_'+lowercase(ServiceNames[IdCmdOffset]);
end;

procedure AddService(Name, Image: string);
begin
  SetLength(ServiceNames, Length(ServiceNames)+1); ServiceNames[High(ServiceNames)] := Name;
  SetLength(ImageNames  , Length(ImageNames  )+1); ImageNames  [High(ImageNames  )] := Image;
end;

procedure TMyContextMenu.RefreshServices;
var
  Reg: TRegistry;
  I: Integer;
  Host, Image: string;
begin
  SetLength(ServiceNames, 0);
  SetLength(ImageNames, 0);
  //AddService('RapidShare', 'UPLOAD');
  AddService('ImageShack', 'IMAGESHACK');
  AddService('MediaFire', 'MEDIAFIRE');

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    Reg.OpenKey('Software\UniUpload', True);
    I := 0;
    while Reg.ValueExists('Custom'+IntToStr(I)) do
    begin
      Host := Reg.ReadString('Custom'+IntToStr(I));
      Inc(I);
      if Copy(Host, 1, 7)='http://' then
      begin
        Delete(Host, 1, 7); // http://
        Host := Copy(Host, 1, Pos('/', Host+'/')-1);
        Image := 'CUSTOM';
        if Host='thecybershadow.net' then
          Image := 'CYBERSHADOW';
        if Pos('freshblood.info', LowerCase(Host))<>0 then
          Image := 'SOUP';
        if Pos('denk.alfahosting.org', LowerCase(Host))<>0 then
          Image := 'WYV';
        AddService(Host, Image);
      end
      else
      if Pos('|', Host)<>0 then
      begin
        Host := Copy(Host, 1, Pos('|', Host)-1);
        AddService(Host, 'LOCAL');
      end;
    end
  finally
    Reg.Free;
  end;

  if(Length(BT)<>Length(ServiceNames)) then
  begin
    for I:=0 to High(BT) do
      if BT[I]<>nil then
        BT[I].Free;
    SetLength(BT, Length(ServiceNames));
    for I:=0 to High(BT) do
      BT[I]:=nil;
  end;
end;

{$R UniUpShl.res}

function TMyContextMenu.AddMenuItems(Menu: HMENU; MenuIndex, IdCmdFirst, IdCmdLast: UINT): UINT;
var
  mii: TMenuItemInfo;
  I, J: Cardinal;
  Add: boolean;
  Ext: string;
begin
  RefreshServices;

  for I:=0 to High(ServiceNames) do
  begin
    if BT[I]=nil then
      BT[I]:=TBitmap.Create;
    BT[I].LoadFromResourceName(HInstance, ImageNames[I]);

    Add:=True;
    for J:=0 to FileNames.Count-1 do
    begin
      Ext:=LowerCase(ExtractFileExt(FileNames[J]));
      if ServiceNames[I]='ImageShack' then
      begin
        Add:=Add and (Pos(Ext, AllowedImageShackExtensions)>0);
        //Add:=Add and ()
      end;
    end;

    if Add then
    begin
      FillChar(mii, SizeOf(mii), 0);
      mii.cbSize := SizeOf(mii);
      mii.fMask := MIIM_ID or MIIM_TYPE or MIIM_CHECKMARKS;
      mii.fType := MFT_STRING;
      mii.fState := MFS_ENABLED;
      mii.dwTypeData := PChar('Upload to '+ServiceNames[I]);
      mii.wID := IdCmdFirst+I;
      mii.hbmpChecked:=BT[I].Handle;
      mii.hbmpUnchecked:=BT[I].Handle;
      InsertMenuItem(Menu, MenuIndex+I, True, mii);
    end;
  end;
  Result := IdCmdFirst+Cardinal(High(ServiceNames));      // Return max id of inserted menu items = IdCmdFirst
end;

procedure TMyContextMenu.ExecuteCommand(IdCmdOffset: UINT);
var
  I: Integer;
begin
  for I:=0 to FileNames.Count-1 do
    if WinExec(PChar('UniUpld "'+ServiceNames[IdCmdOffset]+'" "'+FileNames[I]+'"'), SW_SHOWNORMAL)<=31 then
    begin
      MessageBox(0, 'Error while running UniUpload. Did you install it in a system folder first?', 'Error', MB_ICONERROR);
      Exit;
    end;
end;


initialization
  Initialize(TMyContextMenu, GUID_ContextMenuEntry, 'UniUpload');

end.

