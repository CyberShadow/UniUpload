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
  Classes;

function TMyUploader.GetName: string;
begin
  Result:='MediaFire';
end;

const
  p1 = '------------'+BoundaryTag+#13#10;
  Letters = '2359abcdfghlmnqrtuvwxyz';
  QK_Lookup = '"sharedtabsfileinfo1-qk" value="';

procedure TMyUploader.Execute;
var
  F, M: TMemoryStream;
  S, S2, ID: string;
  I: Integer;
begin
  FreeOnTerminate:=False;
  Status:=usInitializing;
  BytesDone:=0;

  //while not Terminated do Sleep(100);

  try
    F:=TMemoryStream.Create;
    F.LoadFromFile(FileName);
    F.Position:=0;

    S:=p1+'Content-Disposition: form-data; name="file_name0"; filename="'+ExtractFileName(FileName)+'"'#13#10'Content-Type: text/plain'#13#10#13#10;

    M:=TMemoryStream.Create;
    M.Write(S[1], length(S));
    M.CopyFrom(F, F.Size);
    S:=#13#10'------------'+BoundaryTag+'--'#13#10;
    M.Write(S[1], length(S));
    M.Position:=0;

    CreateHttp;
    HTTP.Request.Referer := 'http://www.mediafire.com/';
    
    Randomize;
    ID := '';
    for I:=1 to 11 do
      ID := ID + Letters[Random(Length(Letters))+1];{}

    LoadCookies('http://upload.mediafire.com/');
    S:=HTTP.Post('http://upload.mediafire.com/' + ID + 'p0', M);

    if Pos('url=', S)=0 then
      raise Exception.Create('Invalid server response');
    WriteLn(S);
    Delete(S, 1, Pos('url=', S)+3);
    S := Copy(S, 1, Pos('"', S)-1);
    LoadCookies('http://www.mediafire.com/');
    HTTP.Get(S);

    repeat
      Sleep(250);
      S := HTTP.Get('http://www.mediafire.com/dynamic/verifystatus.php?identifier='+ID);
      
      if Pos('</strong>', S)=0 then continue;
      Delete(S, 1, Pos('</strong>', S)+9);
      S2 := S;
      Delete(S2, 1, Pos('|', S2));
      Delete(S2, 1, Pos('|', S2));
      S2 := Copy(S2, 1, Pos('|', S2)-1);
      S := Copy(S, 1, Pos('|', S)-1);
      CustomStatus := S + ' (' + S2 + '%)';
      Status := usCustom;
    until Pos('All done, links will be available in a moment', S)<>0;
    CustomStatus := 'Fetching download link';

    S := HTTP.Get('http://www.mediafire.com/upload_complete.php?id='+ID);
    if Pos(QK_Lookup, S)=0 then
      raise Exception.Create('Can''t find quick key in response page!');
    Delete(S, 1, Pos(QK_Lookup, S) + Length(QK_Lookup) - 1);
    S := Copy(S, 1, Pos('"', S)-1);
  except
    on E: Exception do
    begin
      Status:=usError;
      ErrorMessage:=E.Message {+'(ID='+ID+')'};
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
    Results[0].Name:='Download link';
    Results[0].Value:='http://www.mediafire.com/?' + S;
    Results[0].URL:=True;

    {
    SetLength(Results, 2);
    Results[1].Name:='ServerResponse';
    Results[1].Value:=S;
    {}
  except
    Status:=usError;
    ErrorMessage:='Malformed results page (bad upload data?) - see BadResults.html';
    SaveString(S, 'BadResults.html');
    Exit;
  end;

  Status:=usDone;
end;

initialization
  RegisterUploader(TMyUploader.Create(True));

end.
