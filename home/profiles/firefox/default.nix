{ config, ... }: {
  programs.firefox = {
    enable = !config.headless;
    profiles = {
      default = {
        path = "profiles/default";
        settings = {
          "browser.startup.page" = 3;
          "browser.compactmode.show" = true;
          "browser.toolbars.bookmarks.showOtherBookmarks" = false;
          "browser.aboutConfig.showWarning" = false;
          "browser.aboutwelcome.enabled" = false;
          "browser.newtabpage.enabled" = false;
          "browser.theme.toolbar-theme" = 0; # force dark
          "extensions.pocket.enabled" = false;
          "extensions.webextensions.restrictedDomains" = "";
          "layers.acceleration.force-enabled" = true;
          "signon.rememberSignons" = false;
          "signon.rememberSignons.visibilityToggle" = false;

          # I expected HM to enable this automatically on userChrome != null, lol
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };
        userChrome =
          let
            css-files = with builtins; filter
              (file: match ".*\\.css$" file != null)
              (attrNames (readDir ./css));
            css-snippets = map (file: builtins.readFile ./css/${file}) css-files;
          in
          builtins.concatStringsSep "\n" css-snippets;
      };
      KEKW = {
        id = 1;
        path = "profiles/kekw";

        inherit (config.programs.firefox.profiles.default) settings userChrome;
      };
      streaming = {
        id = 2;
        path = "profiles/streaming";

        inherit (config.programs.firefox.profiles.default) settings userChrome;
      };
    };
  };
}
