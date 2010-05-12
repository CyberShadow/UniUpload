unit Custom;

interface
uses
  BaseUploader, IdHTTP, SysUtils;

type
  TCustomWebUploader=class(TUploader)
    Host, URL: string;
    constructor Create(aURL: string);
    function GetName: string; override;
    procedure Execute; override;
    end;

  TCustomLocalUploader=class(TUploader)
    Name, Local, URLBase: string;
    constructor Create(Data: string);
    function GetName: string; override;
    procedure Execute; override;
    end;

implementation

uses
  Windows, Classes, StrUtils, Registry, IdURI;

constructor TCustomWebUploader.Create(aURL: string);
begin
  inherited Create(True);
  URL := aURL;
  Host := URL;
  if Copy(Host, 1, 7)<>'http://' then
  begin
    MessageBox(0, 'Custom upload URLs must begin with http:// !', 'Error', MB_ICONERROR);
    Halt;
  end;
  Delete(Host, 1, 7); // http://
  Host := Copy(Host, 1, Pos('/', Host+'/')-1);
end;

function TCustomWebUploader.GetName: string;
begin
  Result := Host;
end;

const
  UploadTemplate=
    '------------'+BoundaryTag+#13#10+
    'Content-Disposition: form-data; name="uploaded"; filename="%filename%"'#13#10+
    'Content-Type: text/plain'#13#10+
    ''#13#10+
    '%data%'#13#10+
    '------------'+BoundaryTag+'--'#13#10;


procedure TCustomWebUploader.Execute;
var
  M: TMemoryStream;
  S, Data: string;
  F: file;
begin
  FreeOnTerminate:=False;
  Status:=usInitializing;
  BytesDone:=0;

  //while not Terminated do Sleep(100);

  try
    AssignFile(F, FileName);
    Reset(F, 1);
    SetLength(Data, FileSize(F));
    BlockRead(F, Data[1], FileSize(F));
    CloseFile(F);

    S:=UploadTemplate;
    S:=AnsiReplaceStr(S, '%filename%', ExtractFileName(FileName));
    S:=AnsiReplaceStr(S, '%data%', Data);

    M:=TMemoryStream.Create;
    M.Write(S[1], length(S));
    M.Position:=0;

    CreateHttp;
    LoadCookies(URL);
    S:=HTTP.Post(URL, M);
  except
    on E: Exception do
      begin
      Status:=usError;
      ErrorMessage:=E.Message;
      Exit;
      end;
    end;

  Status:=usParsingResults;
  {M.Size:=0;
  M.Position:=0;
  M.Write(S[1], length(S));
  M.SaveToFile('result.html');}

  try
    SetLength(Results, 1);

    Results[0].Name:='Result';
    Results[0].Value:=S;
    Results[0].URL:=True;

  except
    Status:=usError;
    ErrorMessage:='Weird error...';
    SaveString(S, 'BadResults.html');
    Exit;
  end;

  Status:=usDone;
end;

// *********************************************************

constructor TCustomLocalUploader.Create(Data: string);
begin
  inherited Create(True);
  
  if Pos('|', Data)=0 then
    raise Exception.Create('Unknown custom uploader format: '+Data);
  Name := Copy(Data, 1, Pos('|', Data)-1);
  Delete(Data, 1, Pos('|', Data));

  if Pos('|', Data)=0 then
    raise Exception.Create('Unknown custom uploader format: '+Data);
  Local := Copy(Data, 1, Pos('|', Data)-1);
  Delete(Data, 1, Pos('|', Data));

  URLBase := Data;
end;

function TCustomLocalUploader.GetName: string;
begin
  Result := Name;
end;

procedure TCustomLocalUploader.Execute;
var
  DestFN: string;
begin
  try
    DestFN := IncludeTrailingPathDelimiter(Local) + ExtractFileName(FileName);
    if FileExists(DestFN) then
      raise Exception.Create('File ' + ExtractFileName(FileName) + ' already exists at destination dir!');
    if not CopyFile(PChar(FileName), PChar(DestFN), True) then
      RaiseLastOSError;

    SetLength(Results, 1);

    Results[0].Name:='Result';
    Results[0].Value:=URLBase + TIdURI.PathEncode(ExtractFileName(FileName));
    Results[0].URL:=True;

    Status:=usDone;
  except
    on E: Exception do
    begin
      Status:=usError;
      ErrorMessage:=E.Message;
      end;
  end;
end;

// *********************************************************

var
  Reg: TRegistry;
  I: Integer;
  S: string;

initialization
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    Reg.OpenKey('Software\UniUpload', True);
    I := 0;
    while Reg.ValueExists('Custom'+IntToStr(I)) do
    begin
      S := Reg.ReadString('Custom'+IntToStr(I));
      if Copy(S, 1, 7)='http://' then
        RegisterUploader(TCustomWebUploader.Create(S))
      else
        RegisterUploader(TCustomLocalUploader.Create(S));
      Inc(I);
    end
  finally
    Reg.Free;
  end;

end.
