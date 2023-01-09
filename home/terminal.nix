{ pkgs, ... }: {
  programs = {
    broot = {
      enable = true;
      settings.verbs = [
        {
          invocation = "mpv";
          external = "mpv --wid=$WINDOWID {file}";
        }
      ];
    };
    direnv.enable = true;
    direnv.nix-direnv.enable = true;
    nix-index.enable = true;
    zoxide.enable = true;
    htop.enable = true;
    starship = {
      enable = true;
      settings = {
        add_newline = false;
        right_format = "$directory";
        character = {
          success_symbol = "λ";
          error_symbol = "λ";
        };
        directory = {
          truncation_length = 10;
          fish_style_pwd_dir_length = 1;
        };
        status = {
          disabled = false;
          format = "[$status](red)";
          pipestatus = true;
          pipestatus_format = "[$pipestatus](red) ";
        };
        nix_shell = {
          symbol = "❄️";
          impure_msg = "";
        };
        git_branch = {
          format = "on [⌥](purple) [$branch(:$remote_branch)](#ff6611) ";
          only_attached = true;
        };
        git_commit.format = "on [⌥](purple) [$hash](#ffaa33) ";
        git_status = {
          format = "(\\([$ahead_behind](#aaaaaa)\\) )(\\[$conflicted$stashed$staged$renamed$modified$deleted$untracked\\] )";
          conflicted = "=$count";
          stashed = "\\$$count";
          staged = "[+$count](#33cc33)";
          renamed = "[~$count](#6666ff)";
          modified = "[~$count](#6666ff)";
          deleted = "[-$count](#cc3333)";
          untracked = "[#$count](#cc3333)";
          ahead = "↑$count";
          behind = "↓$count";
          diverged = "↑$ahead_count↓$behind_count";
        };
      };
    };
  };
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        dimensions = {
          columns = 80;
          lines = 24;
        };
        resize_increments =  true;
      };
      font = let font = "JetBrains Mono"; in {
        normal.family = font;
        italic.family = font;
        bold_italic.family = font;
        size = 14;
      };
      cursor.style.blinking = "On";
      hints = {
        alphabet = "jfkdls;ahgurieowpq";
        enabled = [
          # {
          #   regex = "([-_0-9a-zA-Z/.]+):([0-9]+)";
          #   command = "idea-line";
          #   post_processing = true;
          #   mouse = {
          #     enabled = true;
          #     mods = "None";
          #   };
          #   binding = {
          #     key = "I";
          #     mods = "Control|Shift";
          #   };
          # }
          {
            regex = "(mailto:|gemini:|gopher:|https:|http:|news:|file:|git:|ssh:|ftp:)[^\\u0000-\\u001F\\u007F-\\u009F<>\" {-}\\\\^⟨⟩`]+";
            command = "xdg-open";
            post_processing = true;
            mouse = {
              enabled = true;
              mods = "None";
            };
            binding = {
              key = "U";
              mods = "Control|Shift";
            };
          }
        ];
      };
      key_bindings = [
        {
          key = "T";
          mods = "Control";
          command = {
            program = "bash";
            args = [
              "-c"
              ''
                cur=`grep ~/.config/alacritty/opacity.yml -Poe '(?<=  opacity: )\\d*\\.?\\d+' || true`
                if [[ "$cur" = 0.5 ]]; then
                  new=1.0
                else
                  new=0.5
                fi
                echo -e "window:\\n    opacity: $new" > ~/.config/alacritty/opacity.yml
              ''
            ];
          };
        }
      ];
      import = ["~/.config/alacritty/opacity.yml"];
      colors = {
        primary = {
          background = "#2e3440";
          foreground = "#d8dee9";
          dim_foreground = "#a5abb6";
        };
        cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        vi_mode_cursor = {
          text = "#2e3440";
          cursor = "#d8dee9";
        };
        selection = {
          text = "CellForeground";
          background = "#4c566a";
        };
        search = {
          matches = {
            foreground = "CellBackground";
            background = "#88c0d0";
          };
          footer_bar = {
            background = "#434c5e";
            foreground = "#d8dee9";
          };
        };
        normal = {
          black = "#3b4252";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#88c0d0";
          white = "#e5e9f0";
        };
        bright = {
          black = "#4c566a";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#8fbcbb";
          white = "#eceff4";
        };
        dim = {
          black = "#373e4d";
          red = "#94545d";
          green = "#809575";
          yellow = "#b29e75";
          blue = "#68809a";
          magenta = "#8c738c";
          cyan = "#6d96a5";
          white = "#aeb3bb";
        };
      };
    };
  };
  programs.fish = {
    enable = true;
    shellAbbrs = {
      la = "ls -lAh";
      ll = "ls -lh";
      f = "fuck";
      gst = "git status";
      gco = "git checkout";
      gbd = "git branch -d";
      ggr = "git log --all --decorate --oneline --graph";
    };
    shellInit = ''
      # run zellij if applicable
      if status is-interactive && \
         not set -q ZELLIJ && \
         not test "$TERMINAL_EMULATOR" = JetBrains-JediTerm && \
         not test "$TERM_PROGRAM" = vscode
        exec zellij
      end
      
      # global last status for prompt, separate from $status or $pipestatus
      # to be easily clearable by Ctrl+L (see bindings)
      set -g __last_status 0

      # override Ctrl+L to also clear last status
      bind \cl 'clear -x; set __last_status 0; commandline -f repaint'

      # fix intellij terminal ctrl-arrows
      if test "$TERMINAL_EMULATOR" = JetBrains-JediTerm
        bind \e\[5D backward-word
        bind \e\[5C forward-word
      end
    '';
    functions = {
      fish_title = "echo $_";
      fish_greeting = "set -q IN_NIX_SHELL || fortune -s | lolcat -t";
      fish_right_prompt = "prompt_pwd";
      # __fish_postexec_handler = {
      #   body = ''
      #     set -l ls $pipestatus
      #     # allow disabling this for certain commands
      #     # such as quiet-command-select
      #     if set -q __no_command_stats
      #         set -e __no_command_stats
      #         return
      #     end
      #     set __last_status 0
      #     for s in $ls
      #         if [ $s -ne 0 ]
      #             set __last_status (echo $ls | tr ' ' '|')
      #             break
      #         end
      #     end
      #     set -l d $CMD_DURATION
      #     # 'before-prompt' - print this after the command finished
      #     # but before the nexth prompt
      #     if [ $d -gt 500 ] # only for long commands
      #         echo (set_color 555)"   took $d ms"
      #     end
      #   '';
      #   onEvent = "fish_postexec";
      # };
      # fish_prompt = ''
      #   set -l sym 'λ '

      #   if set -q SSH_CLIENT || set -q SSH_CONNECTION
      #       echo -sn (set_color green)(uname -n)(set_color normal)'|'
      #   end

      #   if set -q IN_NIX_SHELL
      #       echo -sn (set_color blue)nix-shell(set_color normal)'|'
      #   end

      #   if [ "$__last_status" != 0 ]
      #       echo -sn (set_color red)"[$__last_status]"(set_color normal)" "
      #   end

      #   set -l repo_info (git rev-parse 2> /dev/null)
      #   if [ "$status" = 0 ]

      #       set -l staged (git diff --staged --name-status 2> /dev/null | wc -l)
      #       set -l changed (git diff --name-status 2> /dev/null | wc -l)
      #       set -l untracked (git ls-files --others --exclude-standard 2> /dev/null | wc -l)

      #       set -l mod (set_color normal)
      #       if [ "$staged" != 0 ]
      #           set mod $mod(set_color '#33cc33')'⮤'$staged(set_color normal)
      #       end
      #       if [ "$changed" != 0 ]
      #           set mod $mod(set_color '#6666ff')'❖'$changed(set_color normal)
      #       end
      #       if [ "$untracked" != 0 ]
      #           set mod $mod(set_color '#cc3333')'⯈'$untracked
      #       end
      #       set -l branch (git symbolic-ref -q --short HEAD)
      #       if [ -z "$branch" ]
      #           set branch (set_color '#ff6611')(git rev-parse --short HEAD)
      #       else
      #           set branch (set_color '#ffaa33')$branch
      #       end
      #       set -l diffs ""
      #       set -l up (git rev-list @\{u\}..@ --count 2> /dev/null)
      #       if [ "$up" != 0 ]; and [ "$status" = 0 ]
      #           set diffs $up'↑'
      #       end
      #       set -l down (git rev-list @..@\{u\} --count 2> /dev/null)
      #       if [ "$down" != 0 ]; and [ "$status" = 0 ]
      #           set diffs $diffs$down'↓'
      #       end
      #       if [ ! -z "$diffs" ]
      #           set diffs (set_color normal)'('(set_color '#aaaaaa')$diffs(set_color normal)')'
      #       end
      #       echo -sn (set_color purple) '⌥' $branch $diffs $mod (set_color normal) '|'
      #   end
      #   if [ (id -u) = 0 ]
      #       echo -s ' ' (set_color '#ff6666') $sym (set_color normal)
      #   else
      #       echo -s $sym
      #   end
      # '';
      bool = "and echo true; or echo false";
      fuck = ''
        set -l f (math (cat ~/.fucks_given 2>/dev/null; or echo 0) + 1)
        echo "$f fucks given"
        echo $f > ~/.fucks_given
        commandline -i "sudo $history[1]"
      '';
      zwj = "echo -ne '\\xe2\\x80\\x8d' | xclip -i";

      dmesg = "command dmesg --color=always | less -R +G";
      ls = {
        body = "command ls --color=auto --classify=auto $argv";
        wraps = "ls";
      };
      sudo = "command sudo -s $argv";

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
      mpvt = "mpv --wid=$WINDOWID $argv";
    };
  };
}
