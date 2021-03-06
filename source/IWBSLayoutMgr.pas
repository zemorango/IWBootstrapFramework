unit IWBSLayoutMgr;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils, Vcl.Controls,
  IWContainerLayout, IWRenderContext, IWBaseHTMLInterfaces, IWBaseRenderContext, IW.Common.RenderStream, IWHTMLTag;

type

  TIWBSRenderingSortMethod = (bsrmSortYX, bsrmSortXY);

  TIWBSPageOption = (bslyNoConflictButton, bslyEnablePolyfill);

  TIWBSPageOptions = set of TIWBSPageOption;

  TIWBSLayoutMgr = class(TIWContainerLayout)
  private
    FPageOptions: TIWBSPageOptions;
  protected
    procedure InitControl; override;
  public
    constructor Create(AOnwer: TComponent); override;
    procedure ProcessControl(AContainerContext: TIWContainerContext; APageContext: TIWBaseHTMLPageContext; AControl: IIWBaseHTMLComponent); override;
    procedure ProcessForm(ABuffer, ATmpBuf: TIWRenderStream; APage: TIWBasePageContext);
    procedure Process(ABuffer: TIWRenderStream; AContainerContext: TIWContainerContext; aPage: TIWBasePageContext); override;
  published
    property BSPageOptions: TIWBSPageOptions read FPageOptions write FPageOptions default [bslyEnablePolyfill];
  end;

var
  gIWBSLibraryPath: string = '/iwbs';
  gIWBSRefreshCacheParam: string;
  gIWBSjqlibversion: string = '1.11.3';
  gIWBSbslibversion: string = '3.3.5';

  gIWBSRenderingSortMethod: TIWBSRenderingSortMethod = bsrmSortYX;
  gIWBSRenderingGridPrecision: integer = 12;

  gCmpResponsiveTabs: boolean = False;

implementation

uses
  IWBaseForm, IWGlobal, IWHTML40Interfaces, IWTypes, IWHTMLContainer, IWBaseInterfaces, IWBaseControl, IWLists,
  IWRegion, IW.Common.Strings,
  IWBSRegionCommon;

constructor TIWBSLayoutMgr.Create(AOnwer: TComponent);
begin
  inherited;
  FPageOptions := [bslyEnablePolyfill];
end;

procedure TIWBSLayoutMgr.InitControl;
begin
  inherited;
  SetAllowFrames(true);
  SetLayoutType(ltFlow);
end;

procedure TIWBSLayoutMgr.ProcessForm(ABuffer, ATmpBuf: TIWRenderStream; APage: TIWBasePageContext);
var
  LPageContext: TIWPageContext40;
  LTerminated: Boolean;
  FLibPath: string;
begin

  // get library path
  if AnsiEndsStr('/', gSC.URLBase) then
    FLibPath := Copy(gSC.URLBase, 1, Length(gSC.URLBase)-1)
  else
    FLibPath := gSC.URLBase;
  if gIWBSLibraryPath <> '' then begin
    TString.ForcePreFix(gIWBSLibraryPath, '/');
    FLibPath := FLibPath + gIWBSLibraryPath;
  end;
  TString.ForcePreFix(FLibPath, '/');
  TString.ForceSuffix(FLibPath, '/');

  LPageContext := TIWPageContext40(APage);
  LTerminated := Assigned(LPageContext.WebApplication) and LPageContext.WebApplication.Terminated;

  // check if internal jquery is disable and also check if IW version is 14.0.38 or above.
  if gSC.JavaScriptOptions.RenderjQuery then
    raise Exception.Create('Please, disable JavaScriptOptions.RenderjQuery option in server controler');

  ABuffer.WriteLine(LPageContext.DocType);
  ABuffer.WriteLine(gHtmlStart);
  ABuffer.WriteLine('<title>' + LPageContext.Title + '</title>');

  ABuffer.WriteLine('<meta name="viewport" content="width=device-width, initial-scale=1">');

  ABuffer.WriteLine(PreHeadContent);

  // bootstrap, jquery and iwbs libraries (this is the base)
  ABuffer.WriteLine('<link rel="stylesheet" type="text/css" href="'+FLibPath+'bootstrap-'+gIWBSbslibversion+'/css/bootstrap.min.css">');
  ABuffer.WriteLine('<link rel="stylesheet" type="text/css" href="'+FLibPath+'iwbs.css?v='+gIWBSRefreshCacheParam+'">');
  ABuffer.WriteLine('<script type="text/javascript" src="'+FLibPath+'jquery-'+gIWBSjqlibversion+'.min.js"></script>');
  ABuffer.WriteLine('<script type="text/javascript" src="'+FLibPath+'bootstrap-'+gIWBSbslibversion+'/js/bootstrap.min.js"></script>');
  ABuffer.WriteLine('<script type="text/javascript" src="'+FLibPath+'iwbs.js?v='+gIWBSRefreshCacheParam+'"></script>');

  // add missing html5 functionality to most browsers
  // http://afarkas.github.io/webshim/demos/index.html
  if bslyEnablePolyfill in FPageOptions then
    ABuffer.WriteLine('<script type="text/javascript" src="'+FLibPath+'webshim-1.15.8/js-webshim/minified/polyfiller.js"></script>');

  // libraries for components, we load automatically if component unit is included so user can dinamically create component
  if gCmpResponsiveTabs then begin
    ABuffer.WriteLine('<link rel="stylesheet" type="text/css" href="'+FLibPath+'dyntabs/bootstrap-dynamic-tabs.css?v='+gIWBSRefreshCacheParam+'">');
    ABuffer.WriteLine('<script type="text/javascript" src="'+FLibPath+'dyntabs/bootstrap-dynamic-tabs.js?v='+gIWBSRefreshCacheParam+'"></script>');
  end;

  // disable bootstap button plugin for no conflict with jqButton of jQueryUI framework, required if use CGDevtools buttons
  if bslyNoConflictButton in FPageOptions then
    ABuffer.WriteLine('<script type="text/javascript">$.fn.button.noConflict();</script>');

  ABuffer.WriteLine(ScriptSection(LPageContext));
  ABuffer.WriteLine(HeadContent);
  if LPageContext.StyleTag.Contents.Count > 0 then
    LPageContext.StyleTag.Render(ABuffer);
  ABuffer.WriteLine('</head>');
  if not LTerminated then
    LPageContext.FormTag.Render(ATmpBuf);
  LPageContext.BodyTag.Contents.AddBuffer(ATmpBuf);
  LPageContext.BodyTag.Render(ABuffer);
  ABuffer.WriteLine('</html>');
end;

function ControlRenderingSort(AItem1: Pointer; AItem2: Pointer): Integer;
var
  LTop1, LLeft1, LTop2, LLeft2, LIdx1, LIdx2: integer;
begin
  if TComponent(AItem1) is TControl then
    begin
      LTop1 := TControl(AItem1).Top;
      LLeft1 := TControl(AItem1).Left;
      LIdx1 := TControl(AItem1).ComponentIndex;
    end
  else
    begin
      LTop1 := -1;
      LLeft1 := -1;
      LIdx1 := -1;
    end;
  if TComponent(AItem2) is TControl then
    begin
      LTop2 := TControl(AItem2).Top;
      LLeft2 := TControl(AItem2).Left;
      LIdx2 := TControl(AItem2).ComponentIndex;
    end
  else
    begin
      LTop2 := -1;
      LLeft2 := -1;
      LIdx2 := -1;
    end;

  if gIWBSRenderingSortMethod = bsrmSortYX then
    begin
      Result := LTop1 - LTop2;
      if Abs(Result) < gIWBSRenderingGridPrecision then
        Result := LLeft1 - LLeft2;
    end
  else
    begin
      Result := LLeft1 - LLeft2;
      if Abs(Result) < gIWBSRenderingGridPrecision then
        Result := LTop1 - LTop2;
    end;

  if Result = 0 then
    Result := LIdx1 - LIdx2;
end;

procedure TIWBSLayoutMgr.Process(ABuffer: TIWRenderStream; AContainerContext: TIWContainerContext; aPage: TIWBasePageContext);
var
  LTmp: TIWRenderStream;
  LControls: TList;
  i: Integer;
  LComponent: IIWBaseHTMLComponent;
  xCompContext: TIWCompContext;
  LHTML: TIWHTMLTag;
begin
  LTmp := TIWRenderStream.Create(True, True);
  try

    // TIWBSTabControl (investigate how to move this to IWBSTabControl)
    if Container.InterfaceInstance.ClassNameIs('TIWBSTabControl') then
      LTmp.WriteLine('<div class="tab-content">');

    // render controls
    LControls := TList.Create;
    try
      for i := 0 to AContainerContext.ComponentsCount - 1 do
        LControls.Add(AContainerContext.ComponentsList[i]);
      MergeSortList(LControls, ControlRenderingSort);

      for i := 0 to LControls.Count - 1 do begin
        if isBaseComponent(LControls[i]) then begin
          LComponent := BaseHTMLComponentInterface(LControls[I]);

          xCompContext := TIWCompContext(AContainerContext.ComponentContext[LComponent.HTMLName]);
          if not aContainerContext.CacheControls then begin
            xCompContext.HTMLTag.Free;
            xCompContext.HTMLTag := TIWHTMLTag(BaseComponentInterface(xCompContext.Component).RenderMarkupLanguageTag(xCompContext));
          end;
          LHTML := xCompContext.HTMLTag;

          if LHTML <> nil then
            LComponent.MakeHTMLTag(LHTML, LTmp);
        end;
      end;
    finally
      LControls.Free;
    end;

    // close tabs
    if Container.InterfaceInstance.ClassNameIs('TIWBSTabControl') then
      LTmp.WriteLine('</div>');

    // write to buffer
    if Container.InterfaceInstance is TIWBaseForm then
      ProcessForm(aBuffer, LTmp, aPage)
    else
      aBuffer.Stream.CopyFrom(LTmp.Stream, 0);

  finally
    LTmp.Free;
  end;
end;

procedure TIWBSLayoutMgr.ProcessControl(AContainerContext: TIWContainerContext; APageContext: TIWBaseHTMLPageContext; AControl: IIWBaseHTMLComponent);
var
  LHTML: TIWHTMLTag;
  LStyle: string;
begin
  LHTML := TIWCompContext(AContainerContext.ComponentContext[AControl.HTMLName]).HTMLTag;

  // non IWBS components hacks
  if Assigned(LHTML) then begin
    if AControl.InterfaceInstance.ClassName = 'TIWTabPage' then
      LHTML.Params.Values['class'] := IWBSRegionCommon.TIWTabPage(AControl.InterfaceInstance).CSSClass;

    // bugfix, intraweb ignore StyleRenderOption.UseDisplay
    if not TControl(AControl.InterfaceInstance).Visible and HTML40ControlInterface(AControl.InterfaceInstance).StyleRenderOptions.UseDisplay then begin
      LStyle := LHTML.Params.Values['style'];
      if not AnsiContainsText(LStyle,'display:') then
        LStyle := 'display: none;'+LStyle;
      LHTML.AddStringParam('STYLE', LStyle);
    end;
  end;

  inherited;
end;

initialization
  gIWBSRefreshCacheParam := FormatDateTime('yyyymmddhhnnsszzz', now);

end.
