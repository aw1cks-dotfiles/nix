# Git configuration — converted from dotconfig/.gitconfig
{ ... }:
{
  flake.modules.home.git-config =
    { pkgs, ... }:
    {
      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        enableJujutsuIntegration = true;
        options = {
          line-numbers = true;
          line-numbers-left-format = "";
          line-numbers-right-format = "│ ";
          navigate = true;
          side-by-side = true;
          features = "mellow-barbet aw1cks";
        };
      };

      programs.git = {
        enable = true;

        package = pkgs.gitFull.override {
          withLibsecret = true;
          withSsh = true;
          openssh = pkgs.openssh_gssapi;
        };

        lfs.enable = true;

        ignores = [
          "kls_database.db"
          "**/.claude/settings.local.json"
        ];

        settings = {
          user = {
            email = "alex@awicks.io";
            name = "Alex Wicks";
          };

          advice.addIgnoredFile = false;

          alias = {
            a = "add";
            af = "add --force";
            am = "commit --amend";
            b = "! tig blame";
            bl = "! tig blame";
            br = "branch";
            bri = ''!"f() { git checkout "$(git branch | fzf | awk '{print $NF}')" ;}; f"'';
            c = "commit";
            ca = "commit --amend";
            cf = "commit --amend --no-edit";
            ch = "checkout";
            cl = "clone";
            cm = "commit -m";
            co = "commit";
            d = "diff";
            dg = "difftool --gui";
            di = "diff";
            dt = "difftool";
            f = "fetch";
            fe = "fetch";
            i = "init";
            ic = "! git init && git commit --allow-empty -m 'Initial commit'";
            lo = "! tig log";
            mg = "mergetool --gui";
            me = "merge";
            mt = "mergetool";
            p = "push";
            pb = "! git push -u $(git remote | head -1) $(git rev-parse --abbrev-ref HEAD)";
            pf = "push --force-with-lease --force-if-includes";
            pl = "pull";
            po = "push -u origin";
            pu = "pull";
            r = "remote -v";
            rao = "remote add origin";
            rb = "rebase";
            rbc = "rebase --continue";
            rbi = ''!"f() { git rebase -i --rebase-merges HEAD~''${1} ;}; f"'';
            rbr = "rebase -i --root";
            re = "restore";
            rh = "reset --hard";
            root = "rev-parse --show-toplevel";
            rs = "reset --soft";
            rso = "remote show origin";
            rst = "reset";
            s = "status";
            sh = "show";
            st = "status";
            sta = "stash";
            std = "stash drop";
            stp = "stash pop";
            sw = "switch";
            tree = "log --graph --abbrev-commit --decorate --all --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'";
            w = "clean -fdx";
            wi = "clean -fdX";
            wipe = "clean -fdx";
            # Difftastic
            dlog = "-c diff.external=difft log --ext-diff";
            dshow = "-c diff.external=difft show --ext-diff";
            ddiff = "-c diff.external=difft diff";
            dlo = "-c diff.external=difft log -p --ext-diff";
            dsh = "-c diff.external=difft show --ext-diff";
            ddi = "-c diff.external=difft diff";
          };

          blame.coloring = "highlightRecent";

          color = {
            branch = "auto";
            interactive = "auto";
            status = "auto";
            ui = "auto";
          };
          "color \"branch\"".upstream = "cyan";
          "color \"status\"" = {
            added = "blue";
            branch = "cyan";
            changed = "green";
            deleted = "red";
            untracked = "magenta";
          };

          core = {
            autocrlf = "input";
            whitespace = "-trailing-space";
          };

          diff = {
            mnemonicPrefix = true;
            renames = true;
            relative = true;
            submodule = "log";
            tool = "diffview";
            guitool = "meld";
          };

          difftool.prompt = false;
          "difftool \"diffview\"".cmd = ''nvim -n -c "DiffviewOpen"'';
          "difftool \"meld\"".cmd = ''meld "$LOCAL" "$REMOTE"'';

          fetch = {
            recurseSubmodules = "on-demand";
            prune = true;
          };

          grep.extendedRegexp = true;

          init.defaultBranch = "master";

          log = {
            abbrevCommit = true;
            decorate = false;
            follow = true;
          };

          merge = {
            conflictStyle = "zdiff3";
            ff = true;
            tool = "diffview";
            guitool = "meld";
          };
          "mergetool \"diffview\"".cmd = ''nvim -n -c "DiffviewOpen" "$MERGE"'';
          "mergetool \"meld\"".cmd = ''meld "$LOCAL" "$MERGED" "$REMOTE" --output "$MERGED"'';
          mergetool = {
            keepBackup = false;
            keepTemporaries = false;
            prompt = false;
            writeToTemp = true;
          };

          pull.rebase = "merges";

          push = {
            autoSetupRemote = true;
            default = "upstream";
            followTags = true;
          };

          status = {
            showUntrackedFiles = "all";
            submodulesSummary = true;
          };

          tag.sort = "version:refname";

          # Source: https://github.com/dandavison/delta/blob/acd758f7a08df6c2ac5542a2c5a4034c664a9ed8/themes.gitconfig#L445-L475
          "delta \"mellow-barbet\"" = {
            dark = true;
            syntax-theme = "base16";
            line-numbers = true;
            side-by-side = true;
            file-style = "brightwhite";
            file-decoration-style = "none";
            file-added-label = "[+]";
            file-copied-label = "[==]";
            file-modified-label = "[*]";
            file-removed-label = "[-]";
            file-renamed-label = "[->]";
            hunk-header-decoration-style = "\"#3e3e43\" box ul";
            plus-style = "brightgreen black";
            plus-emph-style = "black green";
            minus-style = "brightred black";
            minus-emph-style = "black red";
            line-numbers-minus-style = "brightred";
            line-numbers-plus-style = "brightgreen";
            line-numbers-left-style = "\"#3e3e43\"";
            line-numbers-right-style = "\"#3e3e43\"";
            line-numbers-zero-style = "\"#57575f\"";
            zero-style = "syntax";
            whitespace-error-style = "black bold";
            blame-code-style = "syntax";
            blame-palette = "\"#161617\" \"#1b1b1d\" \"#2a2a2d\" \"#3e3e43\"";
            merge-conflict-begin-symbol = "~";
            merge-conflict-end-symbol = "~";
            merge-conflict-ours-diff-header-style = "yellow bold";
            merge-conflict-ours-diff-header-decoration-style = "\"#3e3e43\" box";
            merge-conflict-theirs-diff-header-style = "yellow bold";
            merge-conflict-theirs-diff-header-decoration-style = "\"#3e3e43\" box";
          };

          "delta \"aw1cks\"" = {
            syntax-theme = "Catppuccin Mocha";
          };
        };
      };
    };
}
