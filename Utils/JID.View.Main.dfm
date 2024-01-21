object MainView: TMainView
  Left = 0
  Top = 0
  Margins.Left = 5
  Margins.Top = 5
  Margins.Right = 5
  Margins.Bottom = 5
  Caption = 'JID UI'
  ClientHeight = 756
  ClientWidth = 1096
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -21
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  PixelsPerInch = 168
  TextHeight = 30
  object ButtonsPanel: TPanel
    Left = 0
    Top = 695
    Width = 1096
    Height = 61
    Margins.Left = 6
    Margins.Top = 6
    Margins.Right = 6
    Margins.Bottom = 6
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object CloseButton: TButton
      AlignWithMargins = True
      Left = 923
      Top = 6
      Width = 167
      Height = 49
      Margins.Left = 6
      Margins.Top = 6
      Margins.Right = 6
      Margins.Bottom = 6
      Align = alRight
      Caption = '&Close'
      DoubleBuffered = True
      ParentDoubleBuffered = False
      TabOrder = 0
      OnClick = CloseButtonClick
    end
  end
  object IndexJarsPanel: TPanel
    AlignWithMargins = True
    Left = 7
    Top = 0
    Width = 1083
    Height = 253
    Margins.Left = 7
    Margins.Top = 0
    Margins.Right = 6
    Margins.Bottom = 7
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 10
    Padding.Right = 10
    TabOrder = 1
    object IndexFolderPanel: TPanel
      AlignWithMargins = True
      Left = 10
      Top = 93
      Width = 1063
      Height = 76
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 4
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object IndexJarsFolderLabel: TLabel
        AlignWithMargins = True
        Left = 0
        Top = 0
        Width = 1063
        Height = 38
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        Caption = 'Jars Folder:'
        ExplicitWidth = 103
        ExplicitHeight = 30
      end
      object IndexFolderEditPanel: TPanel
        AlignWithMargins = True
        Left = 0
        Top = 38
        Width = 1063
        Height = 38
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 0
        object SelectIndexJarsFolderButton: TSpeedButton
          AlignWithMargins = True
          Left = 1023
          Top = 0
          Width = 40
          Height = 38
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alRight
          Caption = '...'
          OnClick = SelectIndexJarsFolderButtonClick
          ExplicitLeft = 1011
        end
        object IndexJarsFolderEdit: TEdit
          AlignWithMargins = True
          Left = 0
          Top = 0
          Width = 1023
          Height = 38
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          ParentShowHint = False
          ShowHint = True
          TabOrder = 0
        end
      end
    end
    object IndexMatchPanel: TPanel
      AlignWithMargins = True
      Left = 10
      Top = 0
      Width = 1063
      Height = 85
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 8
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 1
      object IndexJarsMatchLabel: TLabel
        AlignWithMargins = True
        Left = 0
        Top = 11
        Width = 1052
        Height = 25
        Margins.Left = 0
        Margins.Top = 11
        Margins.Right = 11
        Margins.Bottom = 11
        Align = alClient
        Caption = 'Match:'
        ExplicitWidth = 64
        ExplicitHeight = 30
      end
      object IndexJarsMatchEdit: TEdit
        AlignWithMargins = True
        Left = 0
        Top = 47
        Width = 1063
        Height = 38
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alBottom
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
      end
    end
    object IndexJarsButtonsPanel: TPanel
      Left = 10
      Top = 192
      Width = 1063
      Height = 61
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alBottom
      BevelOuter = bvNone
      Padding.Left = 4
      Padding.Top = 4
      Padding.Right = 4
      Padding.Bottom = 4
      TabOrder = 2
      object IndexJarsButton: TButton
        AlignWithMargins = True
        Left = 859
        Top = 4
        Width = 200
        Height = 53
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alRight
        Caption = 'Index Jars'
        DoubleBuffered = True
        ParentDoubleBuffered = False
        TabOrder = 0
        OnClick = IndexJarsButtonClick
      end
    end
  end
  object IndexRTLPanel: TPanel
    AlignWithMargins = True
    Left = 7
    Top = 260
    Width = 1083
    Height = 168
    Margins.Left = 7
    Margins.Top = 0
    Margins.Right = 6
    Margins.Bottom = 7
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 10
    Padding.Right = 10
    TabOrder = 2
    object SourceFolderPanel: TPanel
      AlignWithMargins = True
      Left = 10
      Top = 0
      Width = 1063
      Height = 76
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 4
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object SourceFolderLabel: TLabel
        AlignWithMargins = True
        Left = 0
        Top = 0
        Width = 1063
        Height = 38
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        Caption = 'Source Folder:'
        ExplicitWidth = 131
        ExplicitHeight = 30
      end
      object Panel3: TPanel
        AlignWithMargins = True
        Left = 0
        Top = 38
        Width = 1063
        Height = 38
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 0
        object SelectSourceFolderButton: TSpeedButton
          AlignWithMargins = True
          Left = 1023
          Top = 0
          Width = 40
          Height = 38
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alRight
          Caption = '...'
          OnClick = SelectSourceFolderButtonClick
          ExplicitLeft = 1011
        end
        object SourceFolderEdit: TEdit
          AlignWithMargins = True
          Left = 0
          Top = 0
          Width = 1023
          Height = 38
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          ParentShowHint = False
          ShowHint = True
          TabOrder = 0
        end
      end
    end
    object IndexSourceButtonsPanel: TPanel
      Left = 10
      Top = 107
      Width = 1063
      Height = 61
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alBottom
      BevelOuter = bvNone
      Padding.Left = 4
      Padding.Top = 4
      Padding.Right = 4
      Padding.Bottom = 4
      TabOrder = 1
      object IndexRTLButton: TButton
        AlignWithMargins = True
        Left = 859
        Top = 4
        Width = 200
        Height = 53
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alRight
        Caption = 'Index RTL Symbols'
        DoubleBuffered = True
        ParentDoubleBuffered = False
        TabOrder = 0
        OnClick = IndexRTLButtonClick
      end
      object AndroidOnlyCheckBox: TCheckBox
        Left = 267
        Top = 4
        Width = 403
        Height = 53
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alLeft
        Caption = 'Android Only (Index for use with JID)'
        TabOrder = 1
        ExplicitLeft = 239
      end
      object IncludeSourceSubfoldersCheckBox: TCheckBox
        Left = 4
        Top = 4
        Width = 263
        Height = 53
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alLeft
        Caption = 'Include subfolders'
        TabOrder = 2
      end
    end
  end
  object FolderOpenDialog: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <>
    Options = [fdoPickFolders]
    Title = 'Select a folder to index'
    Left = 145
    Top = 499
  end
  object IndexJarsOutputFileOpenDialog: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <
      item
        DisplayName = 'Text files (*.txt)'
        FileMask = '*.txt'
      end
      item
        DisplayName = 'All files (*.*)'
        FileMask = '*.*'
      end>
    Options = []
    Title = 'Select Jar index output file'
    Left = 410
    Top = 499
  end
  object IndexRTLFileOpenDialog: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <
      item
        DisplayName = 'JSON files (*.json)'
        FileMask = '*.json'
      end>
    Options = []
    Title = 'Select RTL index output file'
    Left = 697
    Top = 499
  end
end
