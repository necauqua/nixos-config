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
        userChrome = ''
          /* Hide the sidebar with nice animation when Sidebery sidebar is shown */
          #main-window #titlebar {
            overflow: hidden;
            transition: height 0.1s 0.1s !important;
          }
          #main-window #titlebar {
            height: 2.5em !important;
          }

          /*
           * Preface is ZWS (https://unicode-explorer.com/c/200B),
           * also added in Sidebery settings > General
           */
          #main-window[titlepreface*="​"] #titlebar,
          #main-window[titlepreface*="​"] #tabbrowser-tabs {
            height: 0 !important;
          }

          /* override the above zws thing cuz I never actually need the top bar lol  */
          #main-window #titlebar,
          #main-window #tabbrowser-tabs {
            height: 0 !important;
          }

          /* Hide Sidebery sidebar title */
          #sidebar-box[sidebarcommand="_3c078156-979c-498b-8990-85f7987dd929_-sidebar-action"] > #sidebar-header {
            visibility: collapse !important;
          }

          #sidebar-splitter {
            width: 1px !important;
            border-style: unset !important;
          }
          #sidebar-box {
            min-width: unset !important;
            margin-top: -1px;
          }

          /* Autohide */
          :root {
            --uc-sidebar-width: 34px;
            --uc-sidebar-hover-width: 250px;
          }
          #sidebar-box[sidebarcommand="_3c078156-979c-498b-8990-85f7987dd929_-sidebar-action"] {
            min-width: var(--uc-sidebar-width) !important;
            width: var(--uc-sidebar-width) !important;
            z-index: 1;
          }
 
          #sidebar-box[sidebarcommand="_3c078156-979c-498b-8990-85f7987dd929_-sidebar-action"] > #sidebar {
            transition: min-width 115ms linear !important;
            will-change: min-width;
            min-width: var(--uc-sidebar-width) !important;
          }
 
          #sidebar-box[sidebarcommand="_3c078156-979c-498b-8990-85f7987dd929_-sidebar-action"]:hover > #sidebar {
            min-width: var(--uc-sidebar-hover-width) !important;
            transition-delay: 0ms !important
          }

          html:has(.tabbrowser-tab:nth-child(2)) {
            --sidebar-display: initial;
          }
          html:not(:has(.tabbrowser-tab:nth-child(2))) {
            --uc-sidebar-width: 0 !important;
          }
        '';
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
