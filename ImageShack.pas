unit ImageShack;

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
  Classes, StrUtils, RegExpr;

function TMyUploader.GetName: string;
begin
  Result:='ImageShack';
end;

const
 {p1='------------XUCK8dPZJkriz1iPByDULR'#13#10+
     'Content-Disposition: form-data; name="MAX_FILE_SIZE"'#13#10+
     ''#13#10+
     '3145728'#13#10+
     '------------XUCK8dPZJkriz1iPByDULR'#13#10+
     'Content-Disposition: form-data; name="refer"'#13#10+
     ''#13#10+
     ''#13#10+
     '------------XUCK8dPZJkriz1iPByDULR'#13#10;}
  UploadTemplate=
     '------------'+BoundaryTag+#13#10+
     'Content-Disposition: form-data; name="uploadtype"'#13#10+
     ''#13#10+
     'on'#13#10+
     '------------'+BoundaryTag+#13#10+
     'Content-Disposition: form-data; name="fileupload"; filename="%filename%"'#13#10+
     'Content-Type: image/png'#13#10+
     ''#13#10+
     '%data%'#13#10+
     '------------'+BoundaryTag+#13#10+
     'Content-Disposition: form-data; name="url"'#13#10+
     ''#13#10+
     'paste image url here'#13#10+
     '------------'+BoundaryTag+#13#10+
     'Content-Disposition: form-data; name="MAX_FILE_SIZE"'#13#10+
     ''#13#10+
     '3145728'#13#10+
     '------------'+BoundaryTag+#13#10+
     'Content-Disposition: form-data; name="refer"'#13#10+
     ''#13#10+
     ''#13#10+
     '------------'+BoundaryTag+#13#10+
     'Content-Disposition: form-data; name="brand"'#13#10+
     ''#13#10+
     ''#13#10+
     '------------'+BoundaryTag+#13#10+
     'Content-Disposition: form-data; name="optsize"'#13#10+
     ''#13#10+
     '320x320'#13#10+
     '------------'+BoundaryTag+#13#10+
     'Content-Disposition: form-data; name="rembar"'#13#10+
     ''#13#10+
     '1'#13#10+
     '------------'+BoundaryTag+'--'#13#10;


procedure TMyUploader.Execute;
var
  M: TMemoryStream;
  S, Data: string;
  RE: TRegExpr;
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
    S:=AnsiReplaceStr(S, '%filename%', FileName);
    S:=AnsiReplaceStr(S, '%data%', Data);

    M:=TMemoryStream.Create;
    M.Write(S[1], length(S));
    M.Position:=0;

    CreateHttp;
    LoadCookies('http://imageshack.us/');
    S:=HTTP.Post('http://imageshack.us/', M);
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
    // http://img155.imageshack.us/my.php?image=scrshot2dc1.png
    // http://img155.imageshack.us/img155/4831/scrshot2dc1.png
    // http://img200.imageshack.us/i/lastfmf.png/
    RE:=TRegExpr.Create;
    
    RE.Expression := '"(http://img[0-9]+\.imageshack\.us/my\.php\?image=[^"]+)"';
    if RE.Exec(S) then
    begin
      SetLength(Results, Length(Results)+1);
      Results[High(Results)].Name:='Show image link (old)';
      Results[High(Results)].Value:=RE.Match[1];
      Results[High(Results)].URL:=True;
    end;

    RE.Expression := '"(http://img[0-9]+\.imageshack\.us/i/[^/]+/)"';
    if RE.Exec(S) then
    begin
      SetLength(Results, Length(Results)+1);
      Results[High(Results)].Name:='Show image link';
      Results[High(Results)].Value:=RE.Match[1];
      Results[High(Results)].URL:=True;
    end;

    RE.Expression := '"(http://img[0-9]+\.imageshack\.us/img[0-9]+/[0-9]+/[^"]+)"';
    if RE.Exec(S) then
    begin
      SetLength(Results, Length(Results)+1);
      Results[High(Results)].Name:='Direct link';
      Results[High(Results)].Value:=RE.Match[1];
      Results[High(Results)].URL:=True;
    end;
    
    RE.Expression := '"(http://yfrog.com/[^"]+)"';
    if RE.Exec(S) then
    begin
      SetLength(Results, Length(Results)+1);
      Results[High(Results)].Name:='Short link';
      Results[High(Results)].Value:=RE.Match[1];
      Results[High(Results)].URL:=True;
    end;
    
    if Length(Results)=0 then
      raise Exception.Create('Can''t find any links');
  except
    on E: Exception do
    begin
      Status:=usError;
      ErrorMessage:='Malformed results page (bad upload data?) - see BadResults.html ('+E.Message+')';
      SaveString(S, 'BadResults.html');
      Exit;
    end;
  end;

  Status:=usDone;
end;

initialization
  RegisterUploader(TMyUploader.Create(True));

end.
