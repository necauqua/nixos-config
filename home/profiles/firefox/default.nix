{ config, flake-inputs, pkgs, lib, ... }: {
  programs.firefox = {
    enable = !config.headless;
    # set explicitly because of old stateVersion, this is the new default
    configPath = "${config.xdg.configHome}/mozilla/firefox";
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
            css-remote = map (name: "${flake-inputs.csshacks}/chrome/${name}.css") [
              "autohide_toolbox"
              "autohide_sidebar"
              "hide_tabs_toolbar_v2"
            ];

            css-local = with builtins;
              map (file: ./css/${file})
                (filter
                  (file: match ".*\\.css$" file != null)
                  (attrNames (readDir ./css)));

            css-snippets = map builtins.readFile (css-remote ++ css-local);
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

  xdg.mimeApps = lib.mkIf pkgs.stdenv.isLinux {
    enable = !config.headless;
    defaultApplications = {
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "text/html" = "firefox.desktop";
    };
  };

  xdg.configFile = lib.mkIf pkgs.stdenv.isLinux {
    "mimeapps.list".force = !config.headless;
  };
}
