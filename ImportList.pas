{
Copyright (C) 2006-2013 Matteo Salvi

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

unit ImportList;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ComCtrls, VirtualTrees, AppConfig, GTForm, System.UITypes,
  XMLIntf, msxmldom, XMLDoc, ulEnumerations, ulDatabase, DateUtils, xmldom;

type
  TImportListToTree = function(Tree: TVirtualStringTree;Node: IXMLNode;Parent: PVirtualNode): PVirtualNode of object;

  TfrmImportList = class(TGTForm)
    bvl1: TBevel;
    bvl2: TBevel;
    pgcImport: TPageControl;
    tsLaunchers: TTabSheet;
    tsSettings: TTabSheet;
    gbElements: TGroupBox;
    cbImportList: TCheckBox;
    cbImportSettings: TCheckBox;
    gbFile: TGroupBox;
    rgrpLauncher: TRadioGroup;
    lblFile: TLabel;
    btnBrowse: TButton;
    edtPathList: TEdit;
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
    OpenDialog1: TOpenDialog;
    tsProgress: TTabSheet;
    pbImport: TProgressBar;
    lblItems: TLabel;
    imgList: TImage;
    lblList: TLabel;
    lblLauncher: TLabel;
    imgSettings: TImage;
    lblSettings: TLabel;
    procedure btnDeselectAllClick(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure vstListImpGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure FormCreate(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure vstListImpGetImageIndex(Sender: TBaseVirtualTree;
      Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
      var Ghosted: Boolean; var ImageIndex: Integer);
    procedure vstListImpExpanding(Sender: TBaseVirtualTree; Node: PVirtualNode;
      var Allowed: Boolean);
    procedure btnBackClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure edtPathListEnter(Sender: TObject);
    procedure cbImportListClick(Sender: TObject);
    procedure tsLaunchersShow(Sender: TObject);
    procedure tsSettingsShow(Sender: TObject);

    procedure tsListShow(Sender: TObject);
    procedure tsProgressShow(Sender: TObject);
    procedure vstListImpFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure vstListImpDrawText(Sender: TBaseVirtualTree;
      TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      const Text: string; const CellRect: TRect; var DefaultDraw: Boolean);
  private
    { Private declarations }
    procedure ImportSettingsInASuite;
    procedure ImportListInASuite;
    function  TreeImp2Tree(TreeImp, Tree: TVirtualStringTree): Boolean;
    function  GetNumberNodeImp(Sender: TBaseVirtualTree): Integer;
    procedure PopulateTree(Tree: TVirtualStringTree;FilePath: String);
    function ASuite1NodeToTree(Tree: TVirtualStringTree;XMLNode: IXMLNode;
                               Parent: PVirtualNode): PVirtualNode;
    function wppLauncherNodeToTree(Tree: TVirtualStringTree;XMLNode: IXMLNode;
                                    Parent: PVirtualNode): PVirtualNode;
    procedure XMLToTree(Tree: TVirtualStringTree;CallBack: TImportListToTree;
  XMLDoc: TXMLDocument);
    procedure CheckAllItems(State: TCheckState);
    function InternalImportOptions: Boolean;
  public
    { Public declarations }
  end;

var
  frmImportList : TfrmImportList;

implementation

{$R *.dfm}

uses
  Main, ulNodeDataTypes, ulCommonUtils, ulTreeView, udImages, ulAppConfig,
  ulFileFolder, udClassicMenu;

procedure TfrmImportList.btnCancelClick(Sender: TObject);
begin
  Close;
end;

function TfrmImportList.ASuite1NodeToTree(Tree: TVirtualStringTree;XMLNode: IXMLNode;
                                          Parent: PVirtualNode): PVirtualNode;
var
  NodeData : PBaseData;
  schDate, schTime   : string;
  CustomRealNodeData : TvCustomRealNodeData;
begin
  Result := nil;
  if ((XMLNode.HasAttribute('name')) or (XMLNode.NodeName = 'Separator')) and
     ((XMLNode.NodeName = 'Software') or (XMLNode.NodeName = 'Category') or
      (XMLNode.NodeName = 'Separator')) then
  begin
    //Create a new XMLNode
    //Get item type
    if (XMLNode.NodeName = 'Category') then
      Result := Tree.AddChild(Parent, TvCategoryNodeData.Create)
    else
      if (XMLNode.NodeName = 'Software') then
        Result := Tree.AddChild(Parent, TvFileNodeData.Create(vtdtFile))
      else
        if XMLNode.NodeName = 'Separator' then
          Result := Tree.AddChild(Parent, TvSeparatorNodeData.Create);
    //Add checkbox
    Tree.CheckType[Result] := ctTriStateCheckBox;
    NodeData := Tree.GetNodeData(Result);
    NodeData.Data.pNode  := Result;
    CustomRealNodeData   := TvCustomRealNodeData(NodeData.Data);
    //Get base properties
    if (CustomRealNodeData.DataType <> vtdtSeparator) then
    begin
      CustomRealNodeData.Name     := String(XMLNode.Attributes['name']);
      CustomRealNodeData.PathIcon := GetStrPropertyXML(XMLNode, 'PathIcon', '');
      CustomRealNodeData.HideFromMenu := GetBoolPropertyXML(XMLNode, 'HideSoftwareMenu', false);
      CustomRealNodeData.SchMode  := TSchedulerMode(GetIntPropertyXML (XMLNode, 'SchedulerMode',0));
      //Scheduler date and time
      schDate := GetStrPropertyXML(XMLNode, 'SchedulerDate', '');
      schTime := GetStrPropertyXML(XMLNode, 'SchedulerTime', '');
      if (schDate <> '') and (schTime <> '') then
        CustomRealNodeData.SchDateTime := StrToDateTime(schDate + ' ' + schTime);
      //Check if it is a software, so get software properties
      if (CustomRealNodeData.DataType = vtdtFile) then
      begin
        with TvFileNodeData(CustomRealNodeData) do
        begin
          NoMRU       := GetBoolPropertyXML(XMLNode, 'DontInsertMRU',false);
          PathExe     := GetStrPropertyXML (XMLNode, 'PathExe', '');
          Parameters  := GetStrPropertyXML (XMLNode, 'Parameters', '');
          WorkingDir  := GetStrPropertyXML (XMLNode, 'WorkingDir', '');
          WindowState := GetIntPropertyXML (XMLNode, 'WindowState',0);
          ShortcutDesktop := GetBoolPropertyXML(XMLNode, 'ShortcutDesktop',false);
          ActionOnExe := TActionOnExecute(GetIntPropertyXML(XMLNode, 'ActionOnExe',0));
          Autorun     := TAutorunType(GetIntPropertyXML(XMLNode, 'Autorun',0));
          AutorunPos  := GetIntPropertyXML (XMLNode, 'AutorunPosition',0);
        end;
      end;
    end;
  end;
end;

procedure TfrmImportList.btnBackClick(Sender: TObject);
begin
  pgcImport.SelectNextPage(false,false);
  btnBack.Enabled := pgcImport.ActivePageIndex <> 0;
end;

procedure TfrmImportList.btnBrowseClick(Sender: TObject);
begin
  vstListImp.Clear;
  OpenDialog1.InitialDir := ExtractFileDir(edtPathList.text);
  if (OpenDialog1.Execute) then
  begin
    edtPathList.text := OpenDialog1.FileName;
    btnNext.Enabled  := True;
  end;
  SetCurrentDir(SUITE_WORKING_PATH);
end;

procedure TfrmImportList.btnSelectAllClick(Sender: TObject);
begin
  CheckAllItems(csCheckedNormal);
end;

procedure TfrmImportList.cbImportListClick(Sender: TObject);
begin
  btnNext.Enabled := ((cbImportList.Checked) or (cbImportSettings.Checked)) and
                     ((edtPathList.Text <> '') and FileExists(edtPathList.Text));
end;

procedure TfrmImportList.ImportSettingsInASuite;
begin
  //Import settings
  if (cbImportSettings.Checked) then
  begin
    if InternalImportOptions then
      ImagesDM.IcoImages.GetIcon(IMAGE_INDEX_Accept, imgSettings.Picture.Icon)
    else
      ImagesDM.IcoImages.GetIcon(IMAGE_INDEX_Cancel,imgList.Picture.Icon);
  end;
end;

procedure TfrmImportList.ImportListInASuite;
begin
  if (cbImportList.Checked) then
  begin
    //Set progressbar's max
    pbImport.Max := GetNumberNodeImp(vstListImp);
    try
      if TreeImp2Tree(vstListImp,frmMain.vstList) then
        ImagesDM.IcoImages.GetIcon(IMAGE_INDEX_Accept,imgList.Picture.Icon)
      else
        ImagesDM.IcoImages.GetIcon(IMAGE_INDEX_Cancel,imgList.Picture.Icon);
      lblItems.Caption := Format(msgItemsImported,[pbImport.Max]);
    except
      on E : Exception do
      begin
        ShowMessageFmt(msgErrGeneric,[E.ClassName,E.Message],True);
        lblItems.Caption := msgImportFailed;
      end;
    end;
  end;
end;

procedure TfrmImportList.PopulateTree(Tree: TVirtualStringTree;FilePath: String);
var
  DBImp : TDBManager;
  FileName : String;
  FileExt  : String;
begin
  vstListImp.BeginUpdate;
  FileName := LowerCase(ExtractFileName(FilePath));
  FileExt  := ExtractFileExt(FileName);
  //ASuite or wppLauncher
  if (FileExt = EXT_XML) or (FileExt = EXT_XMLBCK) then
  begin
    XMLDocument1.FileName := FilePath;
    XMLDocument1.Active   := True;
      //Identify launcher xml from first node
      //ASuite 1.x
      if (XMLDocument1.DocumentElement.NodeName = 'ASuite') then
        XMLToTree(vstListImp,ASuite1NodeToTree,XMLDocument1)
      else //winPenPack Launcher 1.x
        if ChangeFileExt(FileName,'') = 'winpenpack' then
          XMLToTree(vstListImp,wppLauncherNodeToTree,XMLDocument1);
  end
  else //ASuite 2.x
    if (FileExt = EXT_SQL) or (FileExt = EXT_SQLBCK) then
    begin
      DBImp := TDBManager.Create(FilePath);
      DBImp.ImportData(Tree);
      DBImp.Destroy;
    end;
  vstListImp.EndUpdate;
  ImagesDM.GetChildNodesIcons(Tree, nil, Tree.RootNode);
end;

function TfrmImportList.wppLauncherNodeToTree(Tree: TVirtualStringTree;XMLNode: IXMLNode;
                                               Parent: PVirtualNode): PVirtualNode;
var
  NodeData     : PBaseData;
  CustomRealNodeData : TvCustomRealNodeData;
begin
  Result := nil;
  if ((XMLNode.HasAttribute(Name)) or (XMLNode.NodeName = 'separator')) and
     ((XMLNode.NodeName = 'file') or (XMLNode.NodeName = 'files') or
      (XMLNode.NodeName = 'separator')) then
  begin
    //Create a new XMLNode
    //Get item type
    if (XMLNode.NodeName = 'files') then
      Result := tree.AddChild(Parent, CreateNodeData(vtdtCategory))
    else
      if (XMLNode.NodeName = 'file') then
        Result := tree.AddChild(Parent, CreateNodeData(vtdtFile))
      else
        if XMLNode.NodeName = 'separator' then
          Result := Tree.AddChild(Parent, CreateNodeData(vtdtSeparator));
    //Add checkbox
    Tree.CheckType[Result] := ctTriStateCheckBox;
    NodeData := Tree.GetNodeData(Result);
    NodeData.Data.pNode := Result;
    CustomRealNodeData  := TvCustomRealNodeData(NodeData.Data);
    //Get base properties
    if CustomRealNodeData.DataType <> vtdtSeparator then
    begin
      CustomRealNodeData.Name     := String(XMLNode.Attributes['name']);
      CustomRealNodeData.PathIcon := GetStrPropertyXML(XMLNode,'icon','');
      CustomRealNodeData.HideFromMenu := GetBoolPropertyXML(XMLNode, 'HideSoftwareMenu', false);
      //Check if it is a software, so get software properties
      if (CustomRealNodeData.DataType = vtdtFile) then
      begin
        with TvFileNodeData(CustomRealNodeData) do
        begin
          NoMRU       := GetBoolPropertyXML(XMLNode, 'DontInsertMRU',false);
          PathExe     := GetStrPropertyXML (XMLNode, 'path','');
          Parameters  := GetStrPropertyXML (XMLNode, 'parameters','');
          WorkingDir  := GetStrPropertyXML (XMLNode, 'WorkingDir','');
          WindowState := GetIntPropertyXML (XMLNode, 'WindowState',0);
          ShortcutDesktop := GetBoolPropertyXML(XMLNode, 'ShortcutDesktop',false);
          ActionOnExe := TActionOnExecute(GetIntPropertyXML(XMLNode, 'ActionOnExe',0));
          Autorun     := TAutorunType(GetIntPropertyXML(XMLNode, 'Autorun',0));
          AutorunPos  := GetIntPropertyXML(XMLNode, 'AutorunPosition',0);
        end;
      end;
    end;
  end;
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
    pgcImport.SelectNextPage(true,false);
    btnBack.Enabled := pgcImport.ActivePageIndex <> 0;
  end
  else //Else close import form
    Close;
end;

procedure TfrmImportList.FormCreate(Sender: TObject);
begin
  vstListImp.NodeDataSize := SizeOf(rBaseData);
  vstListImp.Images       := ImagesDM.IcoImages;
  pgcImport.ActivePageIndex := 0;
  //Set imgList and imgSettings's icon
  ImagesDM.IcoImages.GetBitmap(IMAGE_INDEX_Cancel,imgList.Picture.Bitmap);
  ImagesDM.IcoImages.GetBitmap(IMAGE_INDEX_Cancel,imgSettings.Picture.Bitmap);
end;

procedure TfrmImportList.vstListImpDrawText(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: string; const CellRect: TRect; var DefaultDraw: Boolean);
var
  NodeData: TvBaseNodeData;
begin
  NodeData := PBaseData(Sender.GetNodeData(Node)).Data;
  if NodeData.DataType = vtdtSeparator then
  begin
    ClassicMenu.DoDrawCaptionedSeparator(Sender,TargetCanvas,CellRect,NodeData.Name);
    DefaultDraw := False;
  end;
end;

procedure TfrmImportList.vstListImpExpanding(Sender: TBaseVirtualTree;
  Node: PVirtualNode; var Allowed: Boolean);
begin
  ImagesDM.GetChildNodesIcons(Sender, nil, Node);
end;

procedure TfrmImportList.vstListImpFreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  NodeData : PBaseData;
begin
  NodeData := Sender.GetNodeData(Node);
  FreeAndNil(NodeData.Data);
end;

procedure TfrmImportList.vstListImpGetImageIndex(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var ImageIndex: Integer);
var
  NodeData : PvBaseNodeData;
begin
  NodeData   := Sender.GetNodeData(Node);
  ImageIndex := NodeData.ImageIndex;
  if Column = 1 then
    ImageIndex := -1;
end;

procedure TfrmImportList.vstListImpGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  NodeData : PBaseData;
begin
  NodeData := Sender.GetNodeData(Node);
  if Assigned(NodeData) then
  begin
    if (NodeData.Data.DataType = vtdtSeparator) and (NodeData.Data.Name = '') then
      CellText := ' '
    else
      CellText := StringReplace(NodeData.Data.Name, '&&', '&', [rfIgnoreCase,rfReplaceAll]);
  end;
end;

procedure TfrmImportList.XMLToTree(Tree: TVirtualStringTree;CallBack: TImportListToTree;
  XMLDoc: TXMLDocument);
var
  cXMLNode : IXMLNode;

  procedure ProcessNode(XMLNode : IXMLNode;TreeNode : PVirtualNode);
  var
    cNode : IXMLNode;
  begin
    if XMLNode = nil then Exit;
    //Import xml node in vstListImp
    TreeNode := CallBack(vstListImp, XMLNode, TreeNode);
    //Next nodes
    cNode := XMLNode.ChildNodes.First;
    while Assigned(cNode) do
    begin
      ProcessNode(cNode,TreeNode);
      cNode := cNode.NextSibling;
    end;
  end;

begin
  Tree.Clear;
  Tree.BeginUpdate;
  cXMLNode := XMLDoc.DocumentElement.ChildNodes.First;
  while Assigned(cXMLNode) do
  begin
    ProcessNode(cXMLNode,nil);
    cXMLNode := cXMLNode.NextSibling;
  end;
  Tree.EndUpdate;
end;

procedure TfrmImportList.CheckAllItems(State: TCheckState);
var
  tnImp: PVirtualNode;
begin
  tnImp := vstListImp.GetFirst;
  while Assigned(tnImp) do
  begin
    vstListImp.CheckState[tnImp] := State;
    tnImp := tnImp.NextSibling;
  end;
end;

procedure TfrmImportList.edtPathListEnter(Sender: TObject);
begin
  btnNext.Enabled := ((Sender as TEdit).Text <> '') and FileExists((Sender as TEdit).Text);
end;

function TfrmImportList.TreeImp2Tree(TreeImp, Tree: TVirtualStringTree): Boolean;
var
  tnImp : PVirtualNode;
  procedure ProcessTreeItem(tn, tnImp: PVirtualNode);
  var
    NodeData, NodeDataImp : PBaseData;
  begin
    if (tnImp = nil) then Exit;
    NodeDataImp := TreeImp.GetNodeData(tnImp);
    //Import checked item in main list
    if (tnImp.CheckState = csCheckedNormal) or (tnImp.CheckState = csMixedNormal) then
    begin
      //Update progress bar
      pbImport.Position := pbImport.Position + 1;
      lblItems.Caption  := Format(msgProcessingItems, [((pbImport.Position / pbImport.Max) * 100), pbImport.Max]);
      Self.Update;
      //Create new node in vstList
      tn             := Tree.AddChild(tn, CreateNodeData(NodeDataImp.Data.DataType));
      NodeData       := Tree.GetNodeData(tn);
      //Copy from NodeDataImp
      NodeData.Data.Copy(NodeDataImp.Data);
      //Set some properties
      RenameShortcutOnDesktop(NodeData.Data.Name + EXT_LNK,NodeDataImp.Data.Name + EXT_LNK);
      NodeData.Data.Name     := NodeDataImp.Data.Name;
      NodeData.Data.Position := tn.Index;
      NodeData.Data.pNode    := tn;
      NodeData.Data.ParentNode := tn.Parent;
      //Get icon item, only if tn is in first level
      if (NodeData.Data.DataType <> vtdtSeparator) and (Tree.GetNodeLevel(tn) = 0) then
        NodeData.Data.ImageIndex := ImagesDM.GetIconIndex(TvCustomRealNodeData(NodeData.Data));;
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

procedure TfrmImportList.tsLaunchersShow(Sender: TObject);
begin
  lblTitle.Caption := msgImportTitle1;
  btnNext.Caption  := msgNext;
  btnNext.Enabled  := True;
end;

procedure TfrmImportList.tsListShow(Sender: TObject);
begin
  //If cbImportList is checked, import selected list in VirtualTree
  if (cbImportList.Checked) then
  begin
    lblTitle.Caption := msgImportTitle3;
    btnNext.Caption  := msgImport;
    //Import list in temporary vst
    Config.ASuiteState := asImporting;
    PopulateTree(vstListImp, edtPathList.Text);
  end
  else //Else next page
    pgcImport.SelectNextPage(true,false)
end;

procedure TfrmImportList.tsSettingsShow(Sender: TObject);
begin
  lblTitle.Caption := msgImportTitle2;
  btnNext.Enabled  := (edtPathList.Text <> '') and FileExists(edtPathList.Text);
  btnNext.Caption  := msgNext;
  //Change opendialog's filter depending on chosen launcher
  case rgrpLauncher.ItemIndex of
    0: OpenDialog1.Filter:= Format('ASuite 2.x List (*%s, *%s)|*%s;*%s',    [EXT_SQL,EXT_SQLBCK,EXT_SQL,EXT_SQLBCK]);
    1: OpenDialog1.Filter:= Format('ASuite 1.x List (*%s, *%s)|*%s;*%s',    [EXT_XML,EXT_XMLBCK,EXT_XML,EXT_XMLBCK]);
    2: OpenDialog1.Filter:= Format('winPenPack 1.x List (*%s, *%s)|*%s;*%s',[EXT_XML,EXT_XMLBCK,EXT_XML,EXT_XMLBCK]);
  end;
end;

function TfrmImportList.GetNumberNodeImp(Sender: TBaseVirtualTree): Integer;
var
  NumberNode : Integer;
begin
  NumberNode := 0;
  Sender.IterateSubtree(nil, IterateSubTreeProcs.IncNumberNode, @NumberNode, [], True);
  Result := NumberNode;
end;

function TfrmImportList.InternalImportOptions: Boolean;
var
  DBImp  : TDBManager;
  Node, tvFontStyle : IXMLNode;
  ImportFileExt : String;
  I      : Integer;
begin
  Result := False;
  try
    ImportFileExt := LowerCase(ExtractFileExt(edtPathList.Text));
    if (ImportFileExt = EXT_XML) or (ImportFileExt = EXT_XMLBCK) then
    begin
      XMLDocument1.FileName := edtPathList.Text;
      XMLDocument1.Active   := True;
      //ASuite 1.x - wppLauncher
      Node := XMLDocument1.DocumentElement.ChildNodes['Option'];
      //General
      Config.StartWithWindows   := GetBoolPropertyXML(Node, 'StartOnWindowsStartup', false);
      Config.ShowPanelAtStartUp := GetBoolPropertyXML(Node, 'StartUpShowPanel', true);
      Config.ShowMenuAtStartUp  := GetBoolPropertyXML(Node, 'StartUpShowMenu', false);
      //Main Form
      Config.CustomTitleString := GetStrPropertyXML(Node, 'CustomTitleString', APP_TITLE);
      Config.UseCustomTitle    := GetBoolPropertyXML(Node, 'CustomTitle', false);
      Config.HideTabSearch     := GetBoolPropertyXML(Node, 'HideSearch', false);
      //Main Form - Position and size
      Config.HoldSize    := GetBoolPropertyXML(Node, 'HoldSize', false);
      Config.AlwaysOnTop := GetBoolPropertyXML(Node, 'MainOnTop', false);
      //frmMain's size
      frmMain.Width      := GetIntPropertyXML(Node,'ListFormWidth',frmMainWidth);
      frmMain.Height     := GetIntPropertyXML(Node,'ListFormHeight',frmMainHeight);
      //frmMain position
      SetFormPosition(frmMain, GetIntPropertyXML(Node,'ListFormLeft',frmMain.Left),
                               GetIntPropertyXML(Node,'ListFormTop',frmMain.Top));
      frmMain.Position := poDesigned;
      //Main Form - Treevew
      Config.TVBackgroundPath := GetStrPropertyXML(Node, 'BackgroundPath','');
      Config.TVBackground     := GetBoolPropertyXML(Node, 'Background',False);
      Config.TVAutoOpClCats   := GetBoolPropertyXML(Node, 'AutoOpClCategories',False);
      //Treeview Font
      Config.TVFont.Name      := GetStrPropertyXML(Node, 'TreeViewFontName','MS Sans Serif');
      tvFontStyle             := Node.ChildNodes['TreeViewFontStyle'];
      if Assigned(tvFontStyle) then
      begin
        if GetBoolPropertyXML(tvFontStyle,'fsBold',false) then
          Config.TVFont.Style := Config.TVFont.Style + [fsBold];
        if GetBoolPropertyXML(tvFontStyle,'fsItalic',false) then
          Config.TVFont.Style := Config.TVFont.Style + [fsItalic];
        if GetBoolPropertyXML(tvFontStyle,'fsUnderline',false) then
          Config.TVFont.Style := Config.TVFont.Style + [fsUnderline];
        if GetBoolPropertyXML(tvFontStyle,'fsStrikeOut',false) then
          Config.TVFont.Style := Config.TVFont.Style + [fsStrikeOut];
      end;
      Config.TVFont.Size    := GetIntPropertyXML(Node,'TreeViewFontSize',8);
      Config.TVFont.Color   := GetIntPropertyXML(Node,'TreeViewFontColor',clWindowText);
      //MRU
      Config.MRU            := GetBoolPropertyXML(Node, 'ActiveMRU',true);
      Config.SubMenuMRU     := GetBoolPropertyXML(Node, 'ActiveSubMenuMRU',false);
      Config.MRUNumber      := GetIntPropertyXML(Node, 'MRUNumber',5);
      //Backup
      Config.Backup         := GetBoolPropertyXML(Node, 'ActiveBackup',true);
      Config.BackupNumber   := GetIntPropertyXML(Node, 'BackupNumber',5);
      //Other functions
      Config.Autorun        := GetBoolPropertyXML(Node, 'ActiveAutorun',true);
      Config.Cache          := GetBoolPropertyXML(Node, 'ActiveCache',true);
      //Execution
      Config.ActionOnExe    := TActionOnExecute(GetIntPropertyXML(Node, 'ActionOnExe',0));
      Config.RunSingleClick := GetBoolPropertyXML(Node, 'RunSingleClick',false);
      //Trayicon
      Config.TrayIcon           := GetBoolPropertyXML(Node, 'ActiveTrayIcon',true);
      Config.TrayCustomIconPath := GetStrPropertyXML(Node, 'TrayIconPath','');
      Config.ActionClickLeft    := GetIntPropertyXML(Node, 'ActionClickLeft',0);
      Config.ActionClickRight   := GetIntPropertyXML(Node, 'ActionClickRight',2);
      //Mouse sensors
      for I := 0 to 3 do
      begin
        Config.SensorLeftClick[I]  := GetIntPropertyXML(Node.ChildNodes['Mouse'],'SensorLeftClick' + IntToStr(I), 0);
        Config.SensorRightClick[I] := GetIntPropertyXML(Node.ChildNodes['Mouse'],'SensorRightClick' + IntToStr(I), 0);
      end;
    end
    else
      if (ImportFileExt = EXT_SQL) or (ImportFileExt = EXT_SQLBCK)then
      begin
        //ASuite 2.x
        DBImp := TDBManager.Create(edtPathList.Text);
        DBImp.ImportOptions;
        DBImp.Destroy;
      end;
  finally
    Result := True;
    //Config changed and focus vstList (so it repaint)
    Config.Changed := True;
    frmMain.FocusControl(frmMain.vstList);
  end;
end;

procedure TfrmImportList.tsProgressShow(Sender: TObject);
begin
  Config.ASuiteState := asNormal;
  btnBack.Enabled  := False;
  btnNext.Enabled  := False;
  try
    lblTitle.Caption := msgImportProgress;
    //Which launcher?
    case rgrpLauncher.ItemIndex of
      0,1: lblLauncher.Caption := Format(lblLauncher.Caption,['ASuite']);
      2:   lblLauncher.Caption := Format(lblLauncher.Caption,['winPenPack Launcher']);
    end;
    //Set some label and progress bar visibile
    lblList.Enabled  := cbImportList.Checked;
    lblItems.Visible := cbImportList.Checked;
    pbImport.Visible := cbImportList.Checked;
    lblSettings.Enabled := cbImportSettings.Checked;
    //Import list
    ImportListInASuite;
    ImportSettingsInASuite;
  finally
    btnNext.Enabled  := True;
    btnNext.Caption  := msgClose;
    Self.Show;
  end;
end;

end.
