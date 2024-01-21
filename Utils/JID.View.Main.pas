unit JID.View.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Buttons;

type
  TMainView = class(TForm)
    ButtonsPanel: TPanel;
    CloseButton: TButton;
    FolderOpenDialog: TFileOpenDialog;
    IndexFolderPanel: TPanel;
    SelectIndexJarsFolderButton: TSpeedButton;
    IndexJarsFolderLabel: TLabel;
    IndexJarsFolderEdit: TEdit;
    IndexMatchPanel: TPanel;
    IndexJarsMatchLabel: TLabel;
    IndexJarsMatchEdit: TEdit;
    IndexJarsPanel: TPanel;
    IndexFolderEditPanel: TPanel;
    IndexJarsButtonsPanel: TPanel;
    IndexJarsButton: TButton;
    IndexJarsOutputFileOpenDialog: TFileOpenDialog;
    IndexRTLPanel: TPanel;
    SourceFolderPanel: TPanel;
    SourceFolderLabel: TLabel;
    Panel3: TPanel;
    SelectSourceFolderButton: TSpeedButton;
    SourceFolderEdit: TEdit;
    IndexSourceButtonsPanel: TPanel;
    IndexRTLButton: TButton;
    AndroidOnlyCheckBox: TCheckBox;
    IndexRTLFileOpenDialog: TFileOpenDialog;
    IncludeSourceSubfoldersCheckBox: TCheckBox;
    procedure CloseButtonClick(Sender: TObject);
    procedure SelectIndexJarsFolderButtonClick(Sender: TObject);
    procedure IndexJarsButtonClick(Sender: TObject);
    procedure SelectSourceFolderButtonClick(Sender: TObject);
    procedure IndexRTLButtonClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainView: TMainView;

implementation

{$R *.dfm}

uses
  System.IOUtils,
  DW.UnitScan, DW.UnitScan.Persistence.NEON,
  JID.JIDCommand;

procedure TMainView.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

procedure TMainView.IndexJarsButtonClick(Sender: TObject);
begin
  if IndexJarsOutputFileOpenDialog.Execute then
    TJIDCommand.IndexJars(IndexJarsFolderEdit.Text, IndexJarsMatchEdit.Text, IndexJarsOutputFileOpenDialog.FileName);
end;

procedure TMainView.IndexRTLButtonClick(Sender: TObject);
var
  LFoldersOption: TSearchOption;
  LScannerOptions: TSymbolScannerOptions;
  LMaps: TSymbolUnitMaps;
begin
  if IndexRTLFileOpenDialog.Execute then
  begin
    if IncludeSourceSubfoldersCheckBox.Checked then
      LFoldersOption := TSearchOption.soAllDirectories
    else
      LFoldersOption := TSearchOption.soTopDirectoryOnly;
    if AndroidOnlyCheckBox.Checked then
      LScannerOptions := TSymbolScannerOptions.AndroidOnly;
    TUnitSymbolScanner.ScanFolder(SourceFolderEdit.Text, LMaps, LScannerOptions, LFoldersOption);
    LMaps.SaveToFile(IndexRTLFileOpenDialog.FileName);
  end;
end;

procedure TMainView.SelectIndexJarsFolderButtonClick(Sender: TObject);
begin
  FolderOpenDialog.Title := 'Select folder containing jars to index';
  if FolderOpenDialog.Execute then
  begin
    IndexJarsFolderEdit.Text := FolderOpenDialog.FileName;
    if IndexJarsMatchEdit.Text = '' then
      IndexJarsMatchEdit.Text := TPath.GetFileNameWithoutExtension(FolderOpenDialog.FileName) + '*';
  end;
end;

procedure TMainView.SelectSourceFolderButtonClick(Sender: TObject);
begin
  FolderOpenDialog.Title := 'Select source folder';
  if FolderOpenDialog.Execute then
    SourceFolderEdit.Text := FolderOpenDialog.FileName;
end;

end.
