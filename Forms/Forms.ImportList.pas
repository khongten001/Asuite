{
Copyright (C) 2006-2020 Matteo Salvi

Website: http://www.salvadorsoftware.com/

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
}

unit Forms.ImportList;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ComCtrls, VirtualTrees, Kernel.Consts, xmldom,
  XMLIntf, msxmldom, XMLDoc, Kernel.Enumerations, DateUtils, DKLang, JvExMask,
  Vcl.Mask, JvToolEdit;

type
  TfrmImportList = class(TForm)
    bvl1: TBevel;
    bvl2: TBevel;
    pgcImport: TPageControl;
    tsAskFileList: TTabSheet;
    gbFile: TGroupBox;
    lblFile: TLabel;
    tsList: TTabSheet;
    vstListImp: TVirtualStringTree;
    btnSelectAll: TButton;
    btnDeselectAll: TButton;
    btnBack: TButton;
    btnNext: TButton;
    btnCancel: TButton;
    pnlHeader: TPanel;
    lblTitle: TLabel;
    XMLDocument1: TXMLDocument;
    DKLanguageController1: TDKLanguageController;
    edtPathList: TJvFilenameEdit;
    procedure btnDeselectAllClick(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure tsAskFileListShow(Sender: TObject);

    procedure tsListShow(Sender: TObject);
    procedure edtPathListChange(Sender: TObject);
    procedure vstListImpChecked(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    function  GetNumberNodeImp(Sender: TBaseVirtualTree): Integer;
    procedure CheckAllItems(State: TCheckState);
    procedure PopulateTree(Tree: TVirtualStringTree; FilePath: String);
    function  TreeImpToTree(TreeImp, Tree: TVirtualStringTree): Boolean;
  public
    { Public declarations }
    class procedure Execute(AOwner: TComponent);
  end;

var
  frmImportList : TfrmImportList;

implementation

{$R *.dfm}

uses
  Forms.Main, Utility.Misc, AppConfig.Main, VirtualTree.Events, VirtualTree.Methods,
  Utility.FileFolder, Utility.XML, Database.Manager, Kernel.Types, NodeDataTypes.Base,
  DataModules.Icons, Kernel.Logger;

procedure TfrmImportList.btnBackClick(Sender: TObject);
begin
  pgcImport.SelectNextPage(false,false);
  btnBack.Enabled := pgcImport.ActivePageIndex <> 0;
end;

procedure TfrmImportList.btnSelectAllClick(Sender: TObject);
begin
  CheckAllItems(csCheckedNormal);
end;

procedure TfrmImportList.btnDeselectAllClick(Sender: TObject);
begin
  CheckAllItems(csUncheckedNormal);
end;

procedure TfrmImportList.btnNextClick(Sender: TObject);
begin
  //If PageIndex is not last page, show next page
  if pgcImport.ActivePageIndex <> (pgcImport.PageCount - 1) then
  begin
    pgcImport.SelectNextPage(True, false);
    btnBack.Enabled := pgcImport.ActivePageIndex <> 0;
  end
  else //Else close import form
    ModalResult := mrOk;
end;

procedure TfrmImportList.FormCreate(Sender: TObject);
begin
  Config.ASuiteState := lsImporting;
  TVirtualTreeEvents.Create.SetupVSTImportList(vstListImp);
  pgcImport.ActivePageIndex := 0;
end;

procedure TfrmImportList.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Config.ASuiteState := lsNormal;
  if (ModalResult = mrOk) and (vstListImp.HasChildren[vstListImp.RootNode]) then
  begin
    try
      if TreeImpToTree(vstListImp, Config.MainTree) then
      begin
        ShowMessageFmtEx(DKLangConstW('msgItemsImported'), [GetNumberNodeImp(vstListImp)]);
        TASuiteLogger.Info(DKLangConstW('msgItemsImported'), [GetNumberNodeImp(vstListImp)]);
      end;
      TVirtualTreeMethods.Create.GetAllIcons(Config.MainTree, nil);
    except
      on E : Exception do
      begin
        ShowMessageEx(DKLangConstW('msgImportFailed'), True);
        TASuiteLogger.Error(DKLangConstW('msgErrGeneric'), [E.ClassName,E.Message]);
      end;
    end;
  end;
end;

procedure TfrmImportList.CheckAllItems(State: TCheckState);
var
  Node: PVirtualNode;
begin
  Node := vstListImp.GetFirst;
  while Assigned(Node) do
  begin
    vstListImp.CheckState[Node] := State;
    Node := Node.NextSibling;
  end;
end;

procedure TfrmImportList.edtPathListChange(Sender: TObject);
begin
  btnNext.Enabled := (edtPathList.Text <> '') and FileExists(edtPathList.Text);
end;

class procedure TfrmImportList.Execute(AOwner: TComponent);
begin
  TASuiteLogger.Info('Opening form ImportList', []);

  frmImportList := TfrmImportList.Create(AOwner);
  try
    frmImportList.ShowModal;
    frmImportList.vstListImp.Clear;
  finally
    FreeAndNil(frmImportList);
  end;
end;

procedure TfrmImportList.tsListShow(Sender: TObject);
begin
  lblTitle.Caption := DKLangConstW('msgImportTitle3');
  btnNext.Caption  := DKLangConstW('msgImport');
  btnNext.Enabled  := vstListImp.CheckedCount > 0;
  //Import list in temporary vst
  try
    PopulateTree(vstListImp, edtPathList.Text);
  finally
    TVirtualTreeMethods.Create.GetAllIcons(vstListImp, nil);
  end;
end;

procedure TfrmImportList.vstListImpChecked(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
begin
  btnNext.Enabled := Sender.CheckedCount > 0;
end;

procedure TfrmImportList.tsAskFileListShow(Sender: TObject);
begin
  vstListImp.Clear;
  lblTitle.Caption := DKLangConstW('msgImportTitle2');
  btnNext.Enabled  := (edtPathList.Text <> '') and FileExists(edtPathList.Text);
  btnNext.Caption  := DKLangConstW('msgNext');
end;

function TfrmImportList.GetNumberNodeImp(Sender: TBaseVirtualTree): Integer;
var
  NumberNode : Integer;
begin
  NumberNode := 0;
  Sender.IterateSubtree(nil, TVirtualTreeMethods.Create.IncNumberNode, @NumberNode, [], True);
  Result := NumberNode;
end;

procedure TfrmImportList.PopulateTree(Tree: TVirtualStringTree;
  FilePath: String);
var
  DBImp : TDBManager;
  FileName : String;
  FileExt  : String;
begin
  TASuiteLogger.Enter('PopulateTree', Self);
  vstListImp.BeginUpdate;
  try
    vstListImp.Clear;
    FileName := LowerCase(ExtractFileName(FilePath));
    FileExt  := ExtractFileExt(FileName);
    //ASuite or wppLauncher
    if (FileExt = EXT_XML) or (FileExt = EXT_XMLBCK) then
    begin
      XMLDocument1.FileName := FilePath;
      XMLDocument1.Active   := True;
      //Identify launcher xml from first node
      //ASuite 1.x
      if XMLDocument1.DocumentElement.NodeName = 'ASuite' then
        XMLToTree(vstListImp, ltASuite1, XMLDocument1)
      else //winPenPack Launcher 1.x
        if ChangeFileExt(FileName,'') = 'winpenpack' then
          XMLToTree(vstListImp, ltwppLauncher1, XMLDocument1)
        else //PStart 1.x
          if XMLDocument1.DocumentElement.NodeName = 'start' then
            XMLToTree(vstListImp, ltPStart1, XMLDocument1);
    end
    else //BSuite 2.x
      if (FileExt = EXT_SQL) or (FileExt = EXT_SQLBCK) then
      begin
        TASuiteLogger.Info('Found ASuite 2.x List (%s)', [FilePath]);
        DBImp := TDBManager.Create();
        try
          DBImp.Setup(FilePath);
          DBImp.ImportData(Tree);
        finally
          DBImp.Destroy;
        end;
      end;
  finally
    vstListImp.EndUpdate;
  end;
end;

function TfrmImportList.TreeImpToTree(TreeImp,
  Tree: TVirtualStringTree): Boolean;
var
  tnImp : PVirtualNode;

  procedure ProcessTreeItem(tn, tnImp: PVirtualNode);
  var
    NodeData, NodeDataImp : TvBaseNodeData;
  begin
    if (tnImp = nil) then Exit;
    NodeDataImp := TVirtualTreeMethods.Create.GetNodeItemData(tnImp, TreeImp);
    //Import checked item in main list
    if (tnImp.CheckState = csCheckedNormal) or (tnImp.CheckState = csMixedNormal) then
    begin
      //Create new node in vstList
      tn             := TVirtualTreeMethods.Create.AddChildNodeEx(Tree, tn, amInsertAfter, NodeDataImp.DataType, False);
      NodeData       := TVirtualTreeMethods.Create.GetNodeItemData(tn, Tree);
      //Copy from NodeDataImp
      NodeData.Copy(NodeDataImp);
      //Set some properties
      RenameShortcutOnDesktop(NodeData.Name + EXT_LNK, NodeDataImp.Name + EXT_LNK);
      NodeData.Name     := NodeDataImp.Name;
      NodeData.Position := tn.Index;
    end;
    tnImp := tnImp.FirstChild;
    while Assigned(tnImp) do
    begin
      ProcessTreeItem(tn, tnImp);
      tnImp := tnImp.NextSibling;
    end;
  end;

begin
  Tree.BeginUpdate;
  Result := True;
  try
    tnImp := TreeImp.GetFirst;
    while Assigned(tnImp) do
    begin
      ProcessTreeItem(nil, tnImp);
      tnImp := tnImp.NextSibling;
    end;
  except
    Result := False;
  end;
  Tree.EndUpdate;
end;

end.
