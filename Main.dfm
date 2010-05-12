object MainForm: TMainForm
  Left = 871
  Top = 555
  Width = 401
  Height = 127
  Caption = 'UniUpload'
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
