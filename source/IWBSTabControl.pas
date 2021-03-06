unit IWBSTabControl;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, Vcl.Controls, Vcl.Forms, Vcl.Graphics,
  IWVCLBaseContainer, IWApplication, IWBaseRenderContext,
  IWContainer, IWHTMLContainer, IWHTML40Container, IWRegion, IWCompTabControl, IWBaseContainerLayout,
  IWRenderContext, IWHTMLTag, IWBSCommon, IWBSRegionCommon;

type
  TIWBSTabOptions = class(TPersistent)
  private
    FFade: boolean;
    FPills: boolean;
    FJustified: boolean;
    FResponsive: boolean;
    FStacked: boolean;
  public
    constructor Create(AOwner: TComponent);
  published
    property Fade: boolean read FFade write FFade default false;
    property Pills: boolean read FPills write FPills default false;
    property Justified: boolean read FJustified write FJustified default false;
    property Responsive: boolean read FResponsive write FResponsive default false;
    property Stacked: boolean read FStacked write FStacked default false;
  end;

  TIWBSTabControl = class(TIWTabControl)
  private
    FGridOptions: TIWBSGridOptions;
    FLayoutMrg: boolean;
    FTabOptions: TIWBSTabOptions;
    FWebApplication: TIWApplication;
  protected
    procedure SetGridOptions(const Value: TIWBSGridOptions);
    procedure SetTabOptions(const Value: TIWBSTabOptions);
    function InitContainerContext(AWebApplication: TIWApplication): TIWContainerContext; override;
    procedure RenderComponents(AContainerContext: TIWContainerContext; APageContext: TIWBasePageContext); override;
    function RenderHTML(AContext: TIWCompContext): TIWHTMLTag; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property BSGridOptions: TIWBSGridOptions read FGridOptions write SetGridOptions;
    property BSLayoutMgr: boolean read FLayoutMrg write FLayoutMrg default True;
    property BSTabOptions: TIWBSTabOptions read FTabOptions write SetTabOptions;

    property ClipRegion default false;
    property Color default clNone;
  end;

implementation

uses IWLists, IWBSutils, IWBSLayoutMgr;

{$region 'THackCustomRegion'}
type
  THackCustomRegion = class(TIWCustomRegion)
  private
    function CallInheritedRenderHTML(AContext: TIWCompContext): TIWHTMLTag;
  end;

function THackCustomRegion.CallInheritedRenderHTML(AContext: TIWCompContext): TIWHTMLTag;
begin
  Result := inherited RenderHtml(AContext);
end;
{$endregion}

{$region 'TIWBSTabOptions'}
constructor TIWBSTabOptions.Create(AOwner: TComponent);
begin
  FFade := False;
  FPills := False;
  FJustified := False;
  FStacked := False;
end;
{$endregion}

{$region 'TIWBSTabControl'}
constructor TIWBSTabControl.Create(AOwner: TComponent);
begin
  inherited;
  FGridOptions := TIWBSGridOptions.Create;
  FLayoutMrg := True;
  FTabOptions := TIWBSTabOptions.Create(Self);
end;

destructor TIWBSTabControl.Destroy;
begin
  FTabOptions.Free;
  FGridOptions.Free;
  inherited;
end;

procedure TIWBSTabControl.SetGridOptions(const Value: TIWBSGridOptions);
begin
  FGridOptions.Assign(Value);
  invalidate;
end;

procedure TIWBSTabControl.SetTabOptions(const Value: TIWBSTabOptions);
begin
  FTabOptions.Assign(Value);
  invalidate;
end;

function TIWBSTabControl.InitContainerContext(AWebApplication: TIWApplication): TIWContainerContext;
begin
  if FLayoutMrg then
    if not (Self.LayoutMgr is TIWBSLayoutMgr) then
      Self.LayoutMgr := TIWBSLayoutMgr.Create(Self);
  Result := inherited;
end;

procedure TIWBSTabControl.RenderComponents(AContainerContext: TIWContainerContext; APageContext: TIWBasePageContext);
begin
  if FLayoutMrg then
    IWBSPrepareChildComponentsForRender(Self);
  inherited;
end;

function TIWBSTabControl.RenderHTML(AContext: TIWCompContext): TIWHTMLTag;
var
  xHTMLName: string;
  xHTMLInput: string;
  i, tabIndex: integer;
  tagTabs, tag: TIWHTMLTag;
  TabPage: TIWTabPage;
begin
  IWBSDisableRenderOptions(StyleRenderOptions);
  result := THackCustomRegion(Self).CallInheritedRenderHTML(AContext);

  // read only one time
  xHTMLName := HTMLName;
  xHTMLInput := xHTMLName + '_input';

  // default class
  Result.AddClassParam('iwbs-tabs');

  // render bsgrid settings
  Result.AddClassParam(FGridOptions.GetClassString);

  // tabs region
  tagTabs := result.Contents.AddTag('ul');
  tagTabs.AddStringParam('id',xHTMLName+'_tabs');
  tagTabs.AddClassParam('nav');
  if FTabOptions.Pills then
    tagTabs.AddClassParam('nav-pills')
  else
    tagTabs.AddClassParam('nav-tabs');

  if not FTabOptions.Responsive then
    if FTabOptions.Justified then
      tagTabs.AddClassParam('nav-justified');
    if FTabOptions.Stacked then
      tagTabs.AddClassParam('nav-stacked');

  tagTabs.AddStringParam('role', 'tablist');

  // build the tabs
  tabIndex := 0;
  MergeSortList(Pages, TabOrderCompare);
  for i := 0 to Pages.Count-1 do begin
    TabPage := TIWTabPage(FPages.Items[i]);
    tag := tagTabs.Contents.AddTag('li');
    if ActivePage = TabPage.TabOrder then begin
      tag.AddClassParam('active');
      tabIndex := i;
    end;
    tag := tag.Contents.AddTag('a');
    tag.AddStringParam('data-toggle', IfThen(FTabOptions.Pills,'pill','tab'));
    tag.AddStringParam('href', '#'+TabPage.HTMLName);
    tag.AddIntegerParam('tabIndex', i);
    tag.Contents.AddText(TabPage.Title);
  end;

  // add script tag
  Result.Contents.AddText('<script>');
  try
    if FTabOptions.Responsive then
      Result.Contents.AddText('$("#'+xHTMLName+'_tabs'+'").bootstrapDynamicTabs();');

    // save seleted tab on change
    Result.Contents.AddText('$("#'+xHTMLName+'").on("show.bs.tab", function(e){ document.getElementById("'+xHTMLInput+'").value=e.target.tabIndex; });');

    // event async change
    FWebApplication := AContext.WebApplication;
    if Assigned(OnAsyncChange) then begin
      Result.Contents.AddText('$("#'+xHTMLName+'").on("shown.bs.tab", function(e){ executeAjaxEvent("&page="+e.target.tabIndex, null, "'+xHTMLName+'.DoOnAsyncChange", true, null, true); });');
      AContext.WebApplication.RegisterCallBack(xHTMLName+'.DoOnAsyncChange', DoOnAsyncChange);
    end;
  finally
    Result.Contents.AddText('</script>');
  end;

  Result.Contents.AddHiddenField(HTMLName + '_input', xHTMLInput, IntToStr(tabIndex));
end;
{$endregion}

initialization
  gCmpResponsiveTabs := True;

end.
