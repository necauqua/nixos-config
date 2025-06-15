{ pkgs, config, ... }: {
  programs.zellij = {
    enable = false; # using just kitty for now
    settings = {
      theme = "nord";
      pane_frames = false;
    };
  };
  programs.fish = {
    enable = true;
    shellAbbrs = {
      f = "fuck";

      j = "jj";
      ja = "jj all";
      jf = "jj fetch";
      jp = "jj push";
      jt = "jj tug";
      jd = "jj desc -r @";
      jst = "jj status";
      jsq = "jj squash";
      ci.expansion = " jj commit -m '%'";
      ci.setCursor = true;

      ns.expansion = "nix shell nixpkgs#%";
      ns.setCursor = true;
      nr.expansion = "nix run nixpkgs#%";
      nr.setCursor = true;

      gst = "git status";
      gco = "git checkout";
      gbd = "git branch -d";
      ggr = "git log --exclude='refs/jj/keep/*' --all --decorate --oneline --graph";
    };
    shellInit = ''
      ${
        if config.programs.zellij.enable then ''
          # run zellij if applicable
          if status is-interactive && \
             not set -q ZELLIJ && \
             not test "$TERMINAL_EMULATOR" = JetBrains-JediTerm && \
             not test "$TERM_PROGRAM" = vscode && \
             not test "$ZED_TERM" = true
            exec zellij
          end
        '' else ""
      }

      # global last status for prompt, separate from $status or $pipestatus
      # to be easily clearable by Ctrl+L (see bindings)
      set -g __last_status 0

      # override Ctrl+L to also clear last status
      bind \cl 'clear -x; set __last_status 0; commandline -f repaint'

      # default is backward-kill-path-component, word has more word-separating chars,
      # particularly the # that's useful for flake references
      bind \cw backward-kill-word

      # fix intellij terminal ctrl-arrows
      if test "$TERMINAL_EMULATOR" = JetBrains-JediTerm
        bind \e\[5D backward-word
        bind \e\[5C forward-word
      end

      complete -xc fcat -d Function -a '(functions -na)'
    '';
    functions = {
      fish_title = "echo $_";
      fish_greeting = "set -q IN_NIX_SHELL || ${pkgs.fortune}/bin/fortune -s | ${pkgs.lolcat}/bin/lolcat -t 2>/dev/null";
      fish_right_prompt = "prompt_pwd";
      bool = "and echo true; or echo false";
      fuck = ''
        set -l f (math (cat ~/.fucks_given 2>/dev/null; or echo 0) + 1)
        echo "$f fucks given"
        echo $f > ~/.fucks_given
        commandline -i "sudo $history[1]"
      '';
      zwj = "echo -ne '\\xe2\\x80\\x8d' | xclip -i";

      dmesg = "command dmesg --color=always | less -R +G";

      launch = ''
        set -l fixed (string escape -- $argv)
        fish -c "$fixed > /dev/null 2> /dev/null" & disown
      '';
      into = ''
        launch $argv
        exit
      '';
      fcat = ''
        if functions -q -- $argv[1]
            functions --no-details -- $argv[1]
        else
            echo "No function '$argv[1]' found" 1>&2
            return 1
        end
      '';
    };
  };
}
