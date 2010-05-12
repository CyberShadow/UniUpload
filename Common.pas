unit Common;

interface

uses
  BaseUploader;

var
  FileName: string;
  Fields: array of TField;
  Uploader: TUploader;
  FileLength: Integer;
  StartTime, EndTime: TDateTime;

procedure StartUpload;

var
  Error: procedure(Message: String: ErrorIcon: Boolean = True);

implementation

procedure StartUpload;
begin
  
end;

end.