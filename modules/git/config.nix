# Git configuration — converted from dotconfig/.gitconfig
{ ... }:
{
  flake.modules.home.git-config =
    { pkgs, ... }:
    {
      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          side-by-side = false;
          line-numbers = true;
          navigate = true;
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
            pf = "push --force-if-includes";
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
        };
      };
    };
}
