unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, Buttons, Graphics, Clipbrd,
  ShellAPI;

type
  TFieldType=(ftInfo, ftProgress, ftFileName, ftUrl);
  TField=record
    FieldType: TFieldType;
    FieldLabel: TLabel;
    FieldBox: TPanel;
    ProgressImage: TImage;
    InfoEdit: TMemo;
    CopyButton: TSpeedButton;
    OpenButton: TSpeedButton;
    end;

  TMainForm = class(TForm)
    InfoTimer: TTimer;
    procedure FormResize(Sender: TObject);
    procedure InfoTimerTimer(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
    procedure CopyButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure AddField(FieldType: TFieldType; FieldName: string);
    procedure DeleteField;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation
uses
  BaseUploader, DateUtils, Math, ShlObj, ActiveX,
  PngImage;

{$R *.dfm}

procedure TMainForm.AddField(FieldType: TFieldType; FieldName: string);
var
  I, TotalTop: Integer;
begin
  TotalTop:=8+Length(Fields)*24;

  Constraints.MinHeight:=0;
  Constraints.MaxHeight:=0;
  ClientHeight:=TotalTop+24;

  SetLength(Fields, Length(Fields)+1);
  Fields[Length(Fields)-1].FieldType:=FieldType;
  with Fields[Length(Fields)-1] do
    begin
    FieldLabel := TLabel.Create(Self);
    FieldBox := TPanel.Create(Self);
    ProgressImage := TImage.Create(Self);
    InfoEdit := TMemo.Create(Self);
    CopyButton := TSpeedButton.Create(Self);
    OpenButton := TSpeedButton.Create(Self);
    with FieldLabel do
      begin
      //Name := 'FieldLabel';
      Parent := Self;
      Left := 8;
      Top := 2+TotalTop;
      Width := 51;
      Height := 13;
      Caption := FieldName;
      end;
    with FieldBox do
      begin
      //Name := 'FieldBox';
      Parent := Self;
      Left := 104;
      Top := TotalTop;
      Width := Self.ClientWidth-192;
      Height := 17;
      Anchors := [akLeft, akTop, akRight];
      BevelOuter := bvLowered;
      TabOrder := 0;
      end;
    if FieldType in [ftProgress] then
     with ProgressImage do
      begin
      //Name := 'ProgressImage';
      Parent := FieldBox;
      Left := 1;
      Top := 1;
      Width := 183;
      Height := 15;
      Align := alClient;
      end;
    if FieldType in [ftInfo, ftFileName, ftUrl] then
     with InfoEdit do
      begin
      //Name := 'InfoEdit';
      Parent := FieldBox;
      Left := 1;
      Top := 1;
      Width := 183;
      Height := 15;
      Align := alClient;
      BorderStyle := bsNone;
      Color := clBtnFace;
      Text:='';
      WordWrap:=False;
      ReadOnly := True;
      TabOrder := 0;
      WantReturns := False;
      end;
    if FieldType in [ftFileName, ftUrl] then
     with CopyButton do
      begin
      //Name := 'CopyButton';
      Parent := Self;
      Left := Self.ClientWidth-(393-296)+8;
      Top := TotalTop;
      Width := 41;
      Height := 17;
      Anchors := [akTop, akRight];
      Caption := 'Copy';
      Flat := True;
      Tag:=Length(Fields)-1;
      OnClick:=CopyButtonClick;
      end;
    if FieldType in [ftFileName, ftUrl] then
     with OpenButton do
      begin
      //Name := 'OpenButton';
      Parent := Self;
      Left := Self.ClientWidth-(393-344);
      Top := TotalTop;
      Width := 41;
      Height := 17;
      Anchors := [akTop, akRight];
      Caption := 'Open';
      Flat := True;
      Tag:=Length(Fields)-1;
      OnClick:=OpenButtonClick;
      end;
    end;
  for I:=0 to Length(Fields)-1 do
    Fields[i].FieldBox.TabOrder:=I;


  Constraints.MinHeight:=Height;
  Constraints.MaxHeight:=Height;
end;

procedure TMainForm.DeleteField;
var
  TotalTop: Integer;
begin
  with Fields[Length(Fields)-1] do
    begin
    FieldLabel.Free;
    ProgressImage.Free;
    InfoEdit.Free;
    FieldBox.Free;
    CopyButton.Free;
    OpenButton.Free;
    end;
  SetLength(Fields, Length(Fields)-1);

  TotalTop:=8+Length(Fields)*24;

  Constraints.MinHeight:=0;
  Constraints.MaxHeight:=0;
  ClientHeight:=TotalTop+24;
  Constraints.MinHeight:=Height;
  Constraints.MaxHeight:=Height;
end;

function DataSize(Size: Int64):string;
var
  ASize: Integer;
begin
  ASize:=Size;
  Result:='';
  if Size>=0 then
    begin Result:=IntToStr(Size mod 1024)+' B '+Result; Size:=Size div 1024; end;
  if Size>0 then
    begin Result:=IntToStr(Size mod 1024)+' KB, '+Result; Size:=Size div 1024; end;
  if Size>0 then
    begin Result:=IntToStr(Size mod 1024)+' MB, '+Result; Size:=Size div 1024; end;
  if Size>0 then
    begin Result:=IntToStr(Size mod 1024)+' GB, '+Result; Size:=Size div 1024; end;
  if Size>0 then
    begin Result:=IntToStr(Size mod 1024)+' TB, '+Result;{Size:=Size div 1024;}end;
  Result:=IntToStr(ASize)+' bytes ( '+Result+')';
end;

function Pl(i: Integer):string;
begin
  if I=1 then
    Result:=''
  else
    Result:='s';
end;

function TimeString(Seconds: Integer): string;
begin
  Result:='';
  //if Seconds>=0 then
    begin Result:=IntToStr(Seconds mod 60)+' second'+Pl(Seconds mod 60)+Result; Seconds:=Seconds div 60; end;
  if Seconds>0 then
    begin Result:=IntToStr(Seconds mod 60)+' minute'+Pl(Seconds mod 60)+', '+Result; Seconds:=Seconds div 60; end;
  if Seconds>0 then
    begin Result:=IntToStr(Seconds mod 24)+' hour'+Pl(Seconds mod 24)+', '+Result; Seconds:=Seconds div 24; end;
  if Seconds>0 then
    Result:=IntToStr(Seconds)+' day'+Pl(Seconds)+', '+Result;
end;

function Speed(S: Real):string;
begin
  if S<1024 then
    Result:=IntToStr(Trunc(S))+' B/s'
  else
    Result:=FloatToStrF(S/1024, ffFixed, 10, 1)+' KB/s';
end;

const
  CSIDL_MYPICTURES=$0027;

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

procedure TMainForm.FormCreate(Sender: TObject);
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
    MessageBox(0, PChar(
      'UniUpload v1.33'#13#10+
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
      'in the clipboard.'),
      'Error',
      MB_ICONINFORMATION);
    Halt
    end;
  if ParamCount>2 then
    if FileExists(ParamStr(2)) then
      begin
      for I:=2 to ParamCount do
        WinExec(PChar(ParamStr(0)+' '+ParamStr(I)), SW_SHOWNORMAL);
      Halt;
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
            MessageBox(0,
              PChar('PNG error: '+E.Message),
              'Error',
              MB_ICONERROR);
            Halt
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
        MessageBox(0,
          PChar('The clipboard doesn''t contain a supported format.'),
          'Error',
          MB_ICONERROR);
        Halt
      end;
    except
      on E: Exception do
        begin
        MessageBox(0,
          PChar('Clipboard error: '+E.Message),
          'Error',
          MB_ICONERROR);
        Halt
        end;
      end;

  if not FileExists(S) then
    begin
    MessageBox(0,
      PChar('Can''t find the file '+S+'.'),
      'Error',
      MB_ICONERROR);
    Halt
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
    MessageBox(0,
      PChar('I don''t know such an upload provider "'+ParamStr(1)+'".'#13#10+
            'I know of these:'+#13#10+AllProviders),
      'Error',
      MB_ICONERROR);
    Halt;
    end;

  FileName:=ExpandFileName(S);
  FileMode:=fmOpenRead or fmShareDenyWrite;
  try
    AssignFile(F, FileName);
    Reset(F, 1);
    FileLength:=FileSize(F);
    CloseFile(F);
  except
    MessageBox(0,
      PChar('Can''t open the file '+FileName+'.'),
      'Error',
      MB_ICONERROR);
    Halt;
    end;

  Caption:=ExtractFileName(FileName)+' - UniUpload';

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

  AddField(ftInfo, 'Time remaining');      // 7

  Uploader.FileName:=FileName;
  Uploader.Status:=usInitializing;
  Uploader.BytesDone:=0;
  StartTime:=Now;
  Uploader.Resume;
  Sleep(50);
  InfoTimerTimer(nil);
  InfoTimer.Enabled:=True;
end;

var
  LastStatus: TUploadStatus=usInitializing;

procedure TMainForm.InfoTimerTimer(Sender: TObject);
var
  P, I: Integer;
  S: string;
  B: TBitmap;
  Duration, TimeLeft: TDateTime;
  F: TextFile;
begin
  if Uploader=nil then
    Exit;
  if Length(Fields)=0 then
    Exit;

  if LastStatus<>Uploader.Status then
    begin
    if Uploader.Status=usDone then
      begin
      MessageBeep(MB_ICONASTERISK);

      EndTime:=Now;
      while Length(Fields)>6 do
        DeleteField;

      for I:=0 to Length(Uploader.Results)-1 do
        begin
        if Uploader.Results[I].URL then
          AddField(ftURL, Uploader.Results[I].Name)
        else
          AddField(ftInfo, Uploader.Results[I].Name);
        Fields[Length(Fields)-1].InfoEdit.Text:=Uploader.Results[I].Value;
        end;

      try
        AssignFile(F, IncludeTrailingPathDelimiter(GetSystemPath(CSIDL_PERSONAL))+'My uploads.txt');
        try
          Append(F);
        except
          ReWrite(F);
          end;
        for I:=0 to Length(Fields)-1 do
          if Fields[I].FieldType in [ftInfo, ftFileName, ftURL] then
            WriteLn(F, Fields[I].FieldLabel.Caption, '':20-Length(Fields[I].FieldLabel.Caption), ' : ', Fields[I].InfoEdit.Text);
        WriteLn(F, 'Start time           : '+DateTimeToStr(StartTime));
        WriteLn(F, 'End time             : '+DateTimeToStr(EndTime));
        WriteLn(F);
        WriteLn(F, '---------------------------------------------------');
        WriteLn(F);
        CloseFile(F);
      except
        end;

      end;

    if Uploader.Status=usError then
      begin
      EndTime:=Now;
      while Length(Fields)>6 do
        DeleteField;
      AddField(ftInfo, 'Error message');
      S := Uploader.ErrorMessage;
      while Pos(#13#10, S)<>0 do
        S := Copy(S, 1, Pos(#13#10, S)-1) + ' ' + Copy(S, Pos(#13#10, S)+2, MaxInt);
      while Pos(#13, S)<>0 do
        S := Copy(S, 1, Pos(#13, S)-1) + ' ' + Copy(S, Pos(#13, S)+1, MaxInt);
      while Pos(#10, S)<>0 do
        S := Copy(S, 1, Pos(#10, S)-1) + ' ' + Copy(S, Pos(#10, S)+1, MaxInt);
      Fields[Length(Fields)-1].InfoEdit.Text := S;
      end;
    end;
  LastStatus:=Uploader.Status;

  with Fields[3].ProgressImage.Picture.Bitmap, Canvas do
    begin
    Width :=Fields[3].ProgressImage.Width ;
    Height:=Fields[3].ProgressImage.Height;

    if FileLength=0 then
      P:=Width
    else
      P:=Trunc(Width/FileLength*Uploader.BytesDone);
    Brush.Color:=clHighlight;
    FillRect(Rect(0, 0, P, Height));
    Brush.Color:=clWhite;
    FillRect(Rect(P, 0, Width, Height));
    end;

  B:=TBitmap.Create;
  B.Width :=Fields[3].ProgressImage.Width ;
  B.Height:=Fields[3].ProgressImage.Height;
  with B, Canvas do
    begin
    Font.Color:=clHighlight;
    case Uploader.Status of
      usInitializing:
        S:='Initializing';
      usConnecting:
        S:='Connecting';
      usUploading:
        S:=IntToStr(Min(100*Uploader.BytesDone div FileLength, 100))+'%';
      usGettingResults:
        S:='Getting results';
      usParsingResults:
        S:='Parsing results';
      usDone:
        S:='Done';
      usError:
        S:='Error';
      usCustom:
        S:=Uploader.CustomStatus;
      else
        S:='WTF';
      end;
    MainForm.Caption:=S+' - '+ExtractFileName(FileName)+' - UniUpload';
    Application.Title:=MainForm.Caption;
    TextOut((Width-TextWidth(S))div 2, (Height-TextHeight(S))div 2, S);
    end;
  Fields[3].ProgressImage.Picture.Bitmap.Canvas.CopyMode:=$00990066;  // xor + not
  Fields[3].ProgressImage.Picture.Bitmap.Canvas.Draw(0, 0, B);
  B.Free;

  case Uploader.Status of
    usInitializing, usConnecting, usUploading, usGettingResults, usParsingResults:
      begin
      Fields[4].InfoEdit.Text:=TimeString(SecondsBetween(Now, StartTime));
      Duration:=Abs(Now-StartTime);
      if(Duration>0) then
        Fields[5].InfoEdit.Text:=Speed(Uploader.BytesDone/(Duration/OneSecond))
      else
        Fields[5].InfoEdit.Text:='-';
      Fields[6].InfoEdit.Text:=DataSize(Uploader.BytesDone);
      if(Uploader.BytesDone>0)and(FileLength>0)and(Duration>0)then
        begin
        TimeLeft:=FileLength/(Uploader.BytesDone/Duration) - Duration;
        if(TimeLeft>0)then
          Fields[7].InfoEdit.Text:=TimeString(Trunc(TimeLeft/OneSecond))
        else
          Fields[7].InfoEdit.Text:='Almost done...';
        end
      else
        Fields[7].InfoEdit.Text:='-';
      end;
    usDone, usError:
      begin
      Fields[4].InfoEdit.Text:=TimeString(SecondsBetween(EndTime, StartTime));
      if(EndTime<>StartTime) then
        Fields[5].InfoEdit.Text:=Speed(Uploader.BytesDone/((EndTime-StartTime)/OneSecond))
      else
        Fields[5].InfoEdit.Text:='-';
      end;
    end;
end;

procedure TMainForm.CopyButtonClick(Sender: TObject);
begin
  Clipboard.AsText:=Fields[TControl(Sender).Tag].InfoEdit.Text;
end;

procedure TMainForm.OpenButtonClick(Sender: TObject);
begin
  ShellExecute(0, 'open', PChar(Fields[TControl(Sender).Tag].InfoEdit.Text),
    nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if Constraints.MaxHeight<>0 then  // this is a user resize
    InfoTimerTimer(nil);
end;

end.
