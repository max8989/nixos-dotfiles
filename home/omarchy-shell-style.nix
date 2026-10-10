{ palette }:
let
  # Translated from the captured shell.toml. Surfaces may share a color while
  # retaining different opacity/border treatment (launcher vs menus/popups).
  surface = alpha: border: {
    background = palette.background;
    backgroundAlpha = alpha;
    text = palette.text;
    inherit border;
    borderAlpha = 1.0;
    borderWidth = 2;
    scrim = palette.background;
    scrimAlpha = 0.5;
  };
in
{
  fonts = {
    caption = 10;
    bodySmall = 11;
    body = 12;
    subtitle = 13;
    title = 14;
    heading = 16;
    display = 24;
    displayLarge = 28;
    iconSmall = 11;
    icon = 14;
    iconLarge = 18;
  };
  spacing = {
    controlGap = 8;
    controlPaddingX = 10;
    controlPaddingY = 6;
    controlHeight = 28;
    popupRowHeight = 28;
    rowGap = 8;
    rowPaddingX = 12;
    panelGap = 14;
    panelPadding = 18;
    popupPadding = 14;
  };
  controls = {
    normalFillAlpha = 0.04;
    normalBorderAlpha = 0.4;
    hoverFillAlpha = 0.08;
    hoverBorderAlpha = 0.25;
    selectedFillAlpha = 0.18;
    pressedFillAlpha = 0.22;
    selectionFillAlpha = 0.35;
  };
  surfaces = {
    popups = surface 1.0 palette.accent;
    menu = surface 1.0 palette.text;
    launcher = surface 0.95 palette.text;
    tooltip = (surface 0.97 palette.text) // {
      borderWidth = 1;
    };
    notifications = surface 1.0 palette.accent;
    polkit = surface 1.0 palette.accent;
    lock = (surface 1.0 palette.text) // {
      placeholder = palette.text;
      textError = palette.text;
      borderActive = palette.text;
      borderError = palette.text;
    };
  };
}
