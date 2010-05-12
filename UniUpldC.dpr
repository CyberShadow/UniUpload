{$APPTYPE CONSOLE}

program UniUpldC;

uses
{$IFDEF madexcept}
  madExcept, madDisAsm,
{$ENDIF}
  SysUtils, Graphics, PngImage, Clipbrd, Windows, ShlObj, ActiveX,
  BaseUploader in 'BaseUploader.pas',
  ImageShack in 'ImageShack.pas',
  MediaFire in 'MediaFire.pas',
  //RapidShare in 'RapidShare.pas',
  //CyberShadow in 'CyberShadow.pas';
  Custom in 'Custom.pas';

{$I version.inc}

function GetSystemPath(Folder: Integer): string;
var
  PIDL: PItemIDList;
  Path: LPSTR;
  AMalloc: IMalloc;
begin
  Path := StrAlloc(MAX_PATH);
  SHGetSpecialFolderLocation(0, Folder, PIDL);
  if SHGetPathFromIDList(PIDL, Path) then
    Result := Path
  else
    Result := '';
  SHGetMalloc(AMalloc);
  AMalloc.Free(PIDL);
  StrDispose(Path);
end;

var
  FileName: string;
  Uploader: TUploader;
  FileLength: Integer;
  StartTime, EndTime: TDateTime;

var
  I: Integer;
  S, Data, AllProviders: string;
  F: file;
  PNG: TPngObject;
  Pic: TPicture;

begin
  AllProviders:='';
  for I:=0 to Length(Uploaders)-1 do
    AllProviders:=AllProviders+' - '+Uploaders[I].GetName+#13#10;

  if ParamCount=0 then
    begin
    WriteLn(
      'UniUpload v'+Version+#13#10+
      '© 2005-2009 Vladimir Panteleev <thecybershadow@gmail.com>'#13#10+
      //'Dedicated to Phuzion'#13#10+
      ''#13#10+
      'You didn''t specify a service and file(s) to upload.'#13#10+
      'Syntax: UniUpld UploadService FileName [FileName...]'#13#10+
      ''#13#10+
      'Supported providers:'#13#10+
      AllProviders+
      ''#13#10+
      'Specify "Clipboard" as filename to upload the current text or image'#13#10+
      'in the clipboard.');
    Halt
    end;
  if ParamCount>2 then
    if FileExists(ParamStr(2)) then
      begin
      WriteLn('One file at a time, please');
      Halt(1);
      end
    else
      begin
      S:=ParamStr(2);
      for I:=3 to ParamCount do
        S:=S+ParamStr(I);
      end
  else
    S:=ParamStr(2);

  if LowerCase(S)='clipboard' then
    try
      if Clipboard.HasFormat(CF_BITMAP) then
      begin
        S:=GetSystemPath(CSIDL_MYPICTURES);
        if S='' then
          S:=GetSystemPath(CSIDL_PERSONAL);
        S:=IncludeTrailingPathDelimiter(S)+'Uploaded pictures';
        ForceDirectories(S);
        I:=0;
        while FileExists(S+'\'+IntToHex(I, 8)+'.png') do
          Inc(I);
        S:=S+'\'+IntToHex(I, 8)+'.png';

        Pic:=TPicture.Create;
        Pic.Assign(Clipboard);

        PNG:=TPngObject.Create;
        try
          PNG.CompressionLevel:=9;
          PNG.Filters:=[pfNone, pfSub, pfUp, pfAverage, pfPaeth];

          PNG.AssignHandle(Pic.Bitmap.Handle, False, 0);
          PNG.SaveToFile(S);
          PNG.Free;
        except
          on E: Exception do
            begin
            WriteLn('PNG error: '+E.Message);
            Halt(1);
            end;
          end;
      end
      else
      if Clipboard.HasFormat(CF_TEXT) then
      begin
        S:=GetSystemPath(CSIDL_PERSONAL);
        S:=IncludeTrailingPathDelimiter(S)+'Uploaded snippets';
        ForceDirectories(S);
        I:=0;
        while FileExists(S+'\'+IntToHex(I, 8)+'.txt') do
          Inc(I);
        S:=S+'\'+IntToHex(I, 8)+'.txt';

        Data := Clipboard.AsText;
        AssignFile(F, S);
        ReWrite(F, 1);
        BlockWrite(F, Data[1], Length(Data));
        CloseFile(F);
      end
      else
      begin
        WriteLn('The clipboard doesn''t contain a supported format.');
        Halt(1);
      end;
    except
      on E: Exception do
        begin
        WriteLn('Clipboard error: '+E.Message);
        Halt(1);
        end;
      end;

  if not FileExists(S) then
    begin
    WriteLn('Can''t find the file '+S+'.');
    Halt(1);
    end;

  Uploader:=nil;
  for I:=0 to Length(Uploaders)-1 do
    if UpperCase(Uploaders[I].GetName)=UpperCase(ParamStr(1)) then
      Uploader:=Uploaders[I];
  
  if (Uploader=nil) and (Length(ParamStr(1))>=3) then
    for I:=0 to Length(Uploaders)-1 do
      if Pos(UpperCase(ParamStr(1)), UpperCase(Uploaders[I].GetName))<>0 then
        Uploader:=Uploaders[I];

  if Uploader=nil then
    begin
    WriteLn('I don''t know such an upload provider "'+ParamStr(1)+'".'#13#10+
            'I know of these:'+#13#10+AllProviders);
    Halt(1);
    end;

  FileName:=ExpandFileName(S);
  FileMode:=fmOpenRead or fmShareDenyWrite;
  try
    AssignFile(F, FileName);
    Reset(F, 1);
    FileLength:=FileSize(F);
    CloseFile(F);
  except
    WriteLn('Can''t open the file '+FileName+'.');
    Halt(1);
    end;

  {Caption:=ExtractFileName(FileName)+' - UniUpload';

  AddField(ftFileName, 'Local file');      // 0
  Fields[0].InfoEdit.Text:=FileName;

  AddField(ftInfo, 'File size');           // 1
  Fields[1].InfoEdit.Text:=DataSize(FileLength);

  AddField(ftInfo, 'Upload host');         // 2
  Fields[2].InfoEdit.Text:=Uploader.GetName;

  AddField(ftProgress, 'Progress');        // 3

  AddField(ftInfo, 'Time elapsed');        // 4

  AddField(ftInfo, 'Average speed');       // 5

  AddField(ftInfo, 'Uploaded so far');     // 6

  AddField(ftInfo, 'Time remaining');      // 7}

  Uploader.FileName:=FileName;
  Uploader.Status:=usInitializing;
  Uploader.BytesDone:=0;
  StartTime:=Now;
  Uploader.Resume;
  //InfoTimerTimer(nil);
  //InfoTimer.Enabled:=True;
  while not (Uploader.Status in [usDone, usError]) do
    Sleep(10);
  if Uploader.Status=usError then
    WriteLn('Upload error: ', Uploader.ErrorMessage)
  else
    for I:=0 to Length(Uploader.Results)-1 do
      WriteLn(Uploader.Results[I].Name, ': ', Uploader.Results[I].Value);
end.
