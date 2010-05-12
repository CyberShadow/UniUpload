unit BaseUploader;

interface

uses
  Classes, IdComponent, IdHTTP, IdIoHandlerSocket, IdCookieManager;

const
  BoundaryTag = 'UniUpload_FormBoundary';

type
  IdBigInt = Integer; // differs by Indy version
  TResultString=record
    Name, Value: string;
    URL: boolean;
    end;

  TUploadStatus=(usInitializing, usConnecting, usUploading, usGettingResults, usParsingResults, usDone, usError, usCustom);

  TUploader=class(TThread)
    Status: TUploadStatus;
    CustomStatus: string;
    BytesDone: Integer;
    Results: array of TResultString;
    FileName, ErrorMessage: string;
    HTTP: TIdHTTP;
    CookieManager: TIdCookieManager;
    function GetName: string; virtual; abstract;
    procedure CreateHttp;
    procedure LoadCookies(URL: string);
    procedure HttpWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: IdBigInt);
    procedure HttpWorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: IdBigInt);
    procedure HttpWorkEnd(ASender: TObject; AWorkMode: TWorkMode);
    procedure HttpStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
    procedure HttpOnBeforeBind(ASender: TObject);
    end;

var
  Uploaders: array of TUploader;

procedure RegisterUploader(NewUploader: TUploader);
procedure SaveString(S: string; FileName: string);

implementation

uses Windows, WinInet, SysUtils, IdURI;

procedure RegisterUploader(NewUploader: TUploader);
begin
  SetLength(Uploaders, Length(Uploaders)+1);
  Uploaders[Length(Uploaders)-1]:=NewUploader;
end;

procedure TUploader.CreateHttp;
var
  ProxyInfo: PInternetProxyInfo;
  Len: LongWord;
  S: string;
  P: Integer;
begin
  HTTP:=TIdHTTP.Create;
  HTTP.Request.ContentType:='multipart/form-data; boundary=----------'+BoundaryTag;
  HTTP.OnWork:=HttpWork;
  HTTP.OnWorkBegin:=HttpWorkBegin;
  HTTP.OnWorkEnd:=HttpWorkEnd;
  HTTP.OnStatus:=HttpStatus;
  HTTP.OnBeforeBind:=HttpOnBeforeBind;
  HTTP.OnAfterBind:=HttpOnBeforeBind;
  HTTP.HandleRedirects:=True;

  CookieManager := TIdCookieManager.Create;
  HTTP.CookieManager := CookieManager;

  Len := 4096;
  GetMem(ProxyInfo, Len);
  try
    if InternetQueryOption(nil, INTERNET_OPTION_PROXY, ProxyInfo, Len) then
      if ProxyInfo^.dwAccessType = INTERNET_OPEN_TYPE_PROXY then
      begin
        S := ProxyInfo^.lpszProxy;
        P := Pos('http=', S);
        if P<>0 then
        begin
          Delete(S, 1, P+4);
          P := Pos(';', S);
          if P<>0 then
            S := Copy(S, 1, P-1);
        end;
        P := Pos(':', S);
        if P<>0 then
        begin
          HTTP.ProxyParams.ProxyPort := StrToIntDef(Copy(S, P+1, MaxInt), 0);
          HTTP.ProxyParams.ProxyServer := Copy(S, 1, P-1);

          Len := 4096; SetLength(S, Len); 
          if InternetQueryOption(nil, INTERNET_OPTION_PROXY_USERNAME, @S[1], Len) then
          begin
            HTTP.ProxyParams.ProxyUsername := Copy(S, 1, Len);
            HTTP.ProxyParams.BasicAuthentication := True;
          end;
          
          Len := 4096; SetLength(S, Len); 
          if InternetQueryOption(nil, INTERNET_OPTION_PROXY_PASSWORD, @S[1], Len) then
            HTTP.ProxyParams.ProxyPassword := Copy(S, 1, Len);
        end;
      end;
  finally
    FreeMem(ProxyInfo);
  end;
end;

procedure TUploader.LoadCookies(URL: string);
var
  Cookie, CookieData, Host: string;
  C: Cardinal;
begin
  C := $10000;
  SetLength(CookieData, C);
  if not InternetGetCookie(PChar(URL), nil, @CookieData[1], C) then Exit;
  SetLength(CookieData, C);
  //MessageBox(0, PChar(CookieData), nil, 0);

  if Copy(URL, 1, 7)<>'http://' then
    raise Exception.Create('Invalid URL?');
  Host := URL;
  Delete(Host, 1, 7);
  if Pos('/', Host)>0 then
    Host := Copy(Host, 1, Pos('/', Host)-1);

  if CookieData='' then Exit;
  CookieData := CookieData + '; ';
  while CookieData<>'' do
  begin
    Cookie := Copy(CookieData, 1, Pos('; ', CookieData)-1);
    Delete(CookieData, 1, Pos('; ', CookieData)+1);
    HTTP.CookieManager.AddCookie(Cookie, Host);
  end;
  //MessageBox(0, PChar(HTTP.CookieManager.GenerateCookieList(TIdURI.Create(URL))), nil, 0);
end;

procedure TUploader.HttpWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: IdBigInt);
begin
  //MessageBox(0, 'Work', nil, 0);
  if Status=usCustom then Exit;
  case AWorkMode of
    wmWrite: Status:=usUploading;
    wmRead:  Status:=usGettingResults;
    end;
  if AWorkMode=wmWrite then
    BytesDone:=AWorkCount;
end;

procedure TUploader.HttpWorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: IdBigInt);
begin
  //MessageBox(0, 'WorkBegin', nil, 0);
  if Status=usCustom then Exit;
  case AWorkMode of
    wmWrite: Status:=usUploading;
    wmRead:  Status:=usGettingResults;
    end;
end;

procedure TUploader.HttpWorkEnd(ASender: TObject; AWorkMode: TWorkMode);
begin
  //MessageBox(0, 'WorkEnd', nil, 0);
  if Status=usCustom then Exit;
  case AWorkMode of
    wmWrite: Status:=usUploading;
    wmRead:  Status:=usGettingResults;
    end;
end;

procedure TUploader.HttpStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
begin
  if Status=usCustom then Exit;
  case AStatus of
    hsResolving, hsConnecting:       Status:=usConnecting;
    hsDisconnecting, hsDisconnected: Status:=usParsingResults;
    end;
end;

procedure TUploader.HttpOnBeforeBind(ASender: TObject);
begin
  //MessageBox(0, 'Bind', nil, 0);
  {TIdIoHandlerSocket(ASender).InputBuffer.Capacity := 256;
  TIdIoHandlerSocket(ASender).WriteBufferClose;
  TIdIoHandlerSocket(ASender).RecvBufferSize:=256;
  TIdIoHandlerSocket(ASender).SendBufferSize:=256;}
end;

procedure SaveString(S: string; FileName: string);
var
  F: Text;
begin
  try
    Assign(F, FileName);
    ReWrite(F);
    Write(F, S);
    Close(F);
  except
    end;
end;

end.
