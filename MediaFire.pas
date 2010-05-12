unit MediaFire;

interface
uses
  BaseUploader, idHTTP, SysUtils;

type
  TMyUploader=class(TUploader)
    function GetName: string; override;
    procedure Execute; override;
    end;

implementation

uses 
  //Windows,
  Parser2, 
  Classes;

function TMyUploader.GetName: string;
begin
  Result:='MediaFire';
end;

const
  p1 = '------------'+BoundaryTag+#13#10;

procedure TMyUploader.Execute;
var
  F, M: TMemoryStream;
  S, User, UKey, UploadSession, FolderKey, TrackKey, MFULConfig, FileKey, Description, QuickKey, FileError: String;
  E: TNode;
  I: Integer;
begin
  FreeOnTerminate:=False;
  Status:=usInitializing;
  BytesDone:=0;
  Randomize;

  //while not Terminated do Sleep(100);

  try
    F:=TMemoryStream.Create;
    F.LoadFromFile(FileName);
    F.Position:=0;

    S := '';
    CreateHttp;
    HTTP.Request.Referer := 'http://www.mediafire.com/';
    LoadCookies('http://www.mediafire.com/');

    if HTTP.CookieManager.CookieCollection.GetCookieIndex(0, 'ukey')=-1 then
    begin
      Status := usCustom; CustomStatus := 'Fetching new user key';
      HTTP.Get('http://www.mediafire.com/');
      I := HTTP.CookieManager.CookieCollection.GetCookieIndex(0, 'ukey');
      if I=-1 then
        raise Exception.Create('Can''t get "ukey" cookie')
      else
        UKey := HTTP.CookieManager.CookieCollection[I].Value;
    end;

    Status := usCustom; CustomStatus := 'Fetching uploader configuration';
    S := HTTP.Get('http://www.mediafire.com/basicapi/uploaderconfiguration.php?' {+ IntToStr(20000 + Random(500))} + '20117');

    CustomStatus := 'Parsing uploader configuration';
    E := TNode.Create; E.Parse(S);
    UploadSession := E.FindByPath('\MEDIAFIRE\CONFIG\UPLOAD_SESSION').AsText;
    TrackKey      := E.FindByPath('\MEDIAFIRE\CONFIG\TRACKKEY').AsText;
    try
      FolderKey   := E.FindByPath('\MEDIAFIRE\CONFIG\FOLDERKEY').AsText;
    except
      FolderKey   := '';
    end;
    try
      MFULConfig  := E.FindByPath('\MEDIAFIRE\MFULCONFIG').AsText;
    except
      MFULConfig  := '';
    end;
    if (E.FindByPath('\MEDIAFIRE\CONFIG\USER')<>nil) and (E.FindByPath('\MEDIAFIRE\CONFIG\UKEY')<>nil) then
    begin
      User := E.FindByPath('\MEDIAFIRE\CONFIG\USER').AsText;
      UKey := E.FindByPath('\MEDIAFIRE\CONFIG\UKEY').AsText;
    end
    else
    begin
      I := HTTP.CookieManager.CookieCollection.GetCookieIndex(0, 'user');
      if I=-1 then
        User := 'x'
      else
        User := HTTP.CookieManager.CookieCollection[I].Value;
      I := HTTP.CookieManager.CookieCollection.GetCookieIndex(0, 'ukey');
      if I=-1 then
        raise Exception.Create('No ukey?')
      else
        UKey := HTTP.CookieManager.CookieCollection[I].Value;
    end;
    E.Free;

    Status := usInitializing;
    
    M := TMemoryStream.Create;
    S:=p1+'Content-Disposition: form-data; name="Filedata"; filename="'+ExtractFileName(FileName)+'"'#13#10'Content-Type: application/octet-stream'#13#10#13#10;
    M.Write(S[1], Length(S));
    M.CopyFrom(F, F.Size);
    S := #13#10'------------'+BoundaryTag+'--'#13#10;
    M.Write(S[1], length(S));
    M.Position:=0;

    S := 'http://www.mediafire.com/basicapi/douploadnonflash.php?ukey=' + UKey + '&user=' + User + '&uploadkey=' + FolderKey + '&filenum=0&uploader=0&MFULConfig=' + MFULConfig;
    //MessageBox(0, PChar(S), 'URL', 0);
    S := HTTP.Post(S, M);

    if Pos('''', S)=0 then
      raise Exception.Create('Can''t find file key in response');
    Delete(S, 1, Pos(', ''', S)+2);
    FileKey := Copy(S, 1, Pos('''', S)-1);
    //WriteLn(FileKey);

    //MessageBox(0, PChar(FileKey), 'FileKey', 0);

    repeat
      Sleep(250);
      S := HTTP.Get('http://www.mediafire.com/basicapi/pollupload.php?key=' + FileKey + '&MFULConfig=' + MFULConfig);
      //WriteLn(S);
      
      E := TNode.Create; E.Parse(S);
      Description := E.FindByPath('\RESPONSE\DOUPLOAD\DESCRIPTION').AsText;
      QuickKey    := E.FindByPath('\RESPONSE\DOUPLOAD\QUICKKEY').AsText;
      FileError   := E.FindByPath('\RESPONSE\DOUPLOAD\FILEERROR').AsText;
      E.Free;

      CustomStatus := Description;
      Status := usCustom;

      if FileError<>'' then
      begin
        Status:=usError;
        ErrorMessage := 'MediaFire error: ' + FileError;
        Exit;
      end;
    until QuickKey<>'';

    SetLength(Results, 1);
    Results[0].Name:='Download link';
    Results[0].Value:='http://www.mediafire.com/?' + QuickKey;
    Results[0].URL:=True;

  except
    on E: Exception do
    begin
      Status:=usError;
      if S<>'' then
      begin
        ErrorMessage:='Upload error "' + E.Message + '", response saved to BadResults.html';
        SaveString(S, 'BadResults.html');
      end
      else
        ErrorMessage:='Upload error "' + E.Message + '"';
      Exit;
    end;
  end;

  Status:=usDone;
end;

initialization
  RegisterUploader(TMyUploader.Create(True));

end.
