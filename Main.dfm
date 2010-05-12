object MainForm: TMainForm
  Left = 871
  Top = 555
  Caption = 'UniUpload'
  ClientHeight = 91
  ClientWidth = 385
  Color = clBtnFace
  Constraints.MinWidth = 300
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 13
  object InfoTimer: TTimer
    Enabled = False
    Interval = 500
    OnTimer = InfoTimerTimer
    Left = 8
    Top = 8
  end
end
