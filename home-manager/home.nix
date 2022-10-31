# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)

{ inputs, lib, config, pkgs, ... }: {
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors), use something like:
    # inputs.nix-colors.homeManagerModule

    # Feel free to split up your configuration and import pieces of it here.
  ];

  home = {
    username = "james";
    homeDirectory = "/home/james";
  };

  # Add stuff for your user as you see fit:
  home.packages = with pkgs; [
    chromium
    curl
    docker
    docker-compose
    emacs
    fd
    firefox
    flameshot
    git
    htop
    jetbrains.idea-ultimate
    keybase
    lastpass-cli
    mosh
    pass
    pavucontrol
    pidgin
    ripgrep
    slack
    spotify
    teams
    thunderbird

    nodejs
    yarn
  ];

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git.enable = true;

  programs.bash = {
    enable = true;
    historyFileSize = 50000000;
    historyControl = [
      "erasedups"
      "ignoredups"
      "ignorespace"
    ];
    historyIgnore = [
      "ls"
      "cd"
      "exit"
    ];
    shellOptions = [
      "nocaseglob"
      "cdspell"
    ];
    shellAliases = {
      ".." = "cd ..";
      "dl" = "cd ~/Downloads";

      "la" = "ls -laF --color";

      "timer" = "echo \"Timer started. Stop with Ctrl-D.\" && date && time cat && date";

      "g" = "git";
      "d" = "docker";
      "dc" = "docker-compose";
      "untar" = "tar xvf";
    };
    bashrcExtra = ''
          # Simple calculator
      calc() {
        local result=""
        result="$(printf "scale=10;%s\n" "$*" | bc --mathlib | tr -d '\\\n')"
        #            └─ default (when `--mathlib` is used) is 20

        if [[ "$result" == *.* ]]; then
          # improve the output for decimal numbers
          # add "0" for cases like ".5"
          # add "0" for cases like "-.5"
          # remove trailing zeros
          printf "%s" "$result" |
          sed -e 's/^\./0./'  \
            -e 's/^-\./-0./' \
            -e 's/0*$//;s/\.$//'
        else
          printf "%s" "$result"
        fi
        printf "\n"
      }

      # Create a new directory and enter it
      mkd() {
        mkdir -p "$@"
        cd "$@" || exit
      }

      # Make a temporary directory and enter it
      tmpd() {
        local dir
        if [ $# -eq 0 ]; then
          dir=$(mktemp -d)
        else
          dir=$(mktemp -d -t "$\{1}.XXXXXXXXXX")
        fi
        cd "$dir" || exit
      }

      # Create a .tar.gz archive, using `zopfli`, `pigz` or `gzip` for compression
      targz() {
        local tmpFile="$\{1%/}.tar"
        tar -cvf "$\{tmpFile}" --exclude=".DS_Store" "$\{1}" || return 1

        size=$(
        stat -f"%z" "$\{tmpFile}" 2> /dev/null; # OS X `stat`
        stat -c"%s" "$\{tmpFile}" 2> /dev/null # GNU `stat`
        )

        local cmd=""
        if (( size < 52428800 )) && hash zopfli 2> /dev/null; then
          # the .tar file is smaller than 50 MB and Zopfli is available; use it
          cmd="zopfli"
        else
          if hash pigz 2> /dev/null; then
            cmd="pigz"
          else
            cmd="gzip"
          fi
        fi

        echo "Compressing .tar using \`$\{cmd}\`…"
        "$\{cmd}" -v "$\{tmpFile}" || return 1
        [ -f "$\{tmpFile}" ] && rm "$\{tmpFile}"
        echo "$\{tmpFile}.gz created successfully."
      }

      # Determine size of a file or total size of a directory
      fs() {
        if du -b /dev/null > /dev/null 2>&1; then
          local arg=-sbh
        else
          local arg=-sh
        fi
        # shellcheck disable=SC2199
        if [[ -n "$@" ]]; then
          du $arg -- "$@"
        else
          du $arg -- .[^.]* *
        fi
      }

      # Use Git’s colored diff when available
      if hash git &>/dev/null ; then
        diff() {
          git diff --no-index --color-words "$@"
        }
      fi

      # Create a data URL from a file
      dataurl() {
        local mimeType
        mimeType=$(file -b --mime-type "$1")
        if [[ $mimeType == text/* ]]; then
          mimeType="$\{mimeType};charset=utf-8"
        fi
        echo "data:$\{mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')"

      }

      # Start an HTTP server from a directory, optionally specifying the port
      server() {
        open "http://172.17.0.1:$\{1:-8000}" && docker run -it --rm --name pythonServer \
          -v "$PWD":/usr/src/myapp \
          -w /usr/src/myapp \
          -p $\{1:-8000}:$\{1:-8000}\
          python:3 python "$@" -m http.server $\{1:-8000}
      }

      # Compare original and gzipped file size
      gz() {
        local origsize
        origsize=$(wc -c < "$1")
        local gzipsize
        gzipsize=$(gzip -c "$1" | wc -c)
        local ratio
        ratio=$(echo "$gzipsize * 100 / $origsize" | bc -l)
        printf "orig: %d bytes\n" "$origsize"
        printf "gzip: %d bytes (%2.2f%%)\n" "$gzipsize" "$ratio"
      }

      # Syntax-highlight JSON strings or files
      # Usage: `json '{"foo":42}'` or `echo '{"foo":42}' | json`
      json() {
        if [ -t 0 ]; then # argument
          python -mjson.tool <<< "$*" | pygmentize -l javascript
        else # pipe
          python -mjson.tool | pygmentize -l javascript
        fi
      }

      # Run `dig` and display the most useful info
      digga() {
        dig +nocmd "$1" any +multiline +noall +answer
      }

      # `v` with no arguments opens the current directory in Vim, otherwise opens the
      # given location
      v() {
        if [ $# -eq 0 ]; then
          vim .
        else
          vim "$@"
        fi
      }

      # `o` with no arguments opens the current directory, otherwise opens the given
      # location
      o() {
        if [ $# -eq 0 ]; then
          xdg-open .  > /dev/null 2>&1
        else
          xdg-open "$@" > /dev/null 2>&1
        fi
      }

      # check if uri is up
      isup() {
        local uri=$1

        if curl -s --head  --request GET "$uri" | grep "200 OK" > /dev/null ; then
          notify-send --urgency=critical "$uri is down"
        else
          notify-send --urgency=low "$uri is up"
        fi
      }

      # `ds command` runs the command as a detached script
      # Source: http://stackoverflow.com/a/29681504/1432051
      ds(){
        eval "$@" &>/dev/null &disown;
      }


      work-git-clone()
      {
        git clone git@gitlab.com:coreau/$1 ~/$1
      }

      github-git-clone()
      {
        git clone git@github.com:jamesmstone/$1 ~/$1
      }
    '';
  };
  programs.git = {
    enable = true;
    userName = "James Stone";
    userEmail = "jamesmstone@hotmail.com";
    aliases = {
      co = "checkout";

      # View abbreviated SHA, description, and history graph of the latest 20 commits
      l = "log --pretty=oneline -n 20 --graph --abbrev-commit";

      # View the current working tree status using the short format
      s = "status -s";

      # Show the diff between the latest commit and the current state
      d = "!\"git diff-index --quiet HEAD -- || clear; git --no-pager diff --patch-with-stat\"";

      # `git di $number` shows the diff between the state `$number` revisions ago and the current state
      di = "!\"d() { git diff --patch-with-stat HEAD~$1; }; git diff-index --quiet HEAD -- || clear; d\"";

      # Pull in remote changes for the current repository and all its submodules
      p = "!\"git pull; git submodule foreach git pull origin master\"";

      # Clone a repository including all submodules
      c = "clone --recursive";

      # Commit all changes
      ca = "!git add -A && git commit -av";

      # Switch to a branch, creating it if necessary
      go = ''\"!f() { git checkout -b \"$1\" 2> /dev/null || git checkout \"$1\"; }; f\"'';

      # Color graph log view
      graph = ''log --graph --color --pretty=format:"%C(yellow)%H%C(green)%d%C(reset)%n%x20%cd%n%x20%cn%x20(%ce)%n%x20%s%n"'';

      # Show verbose output about tags, branches or remotes
      tags = "tag -l";
      branches = "branch -a";
      remotes = "remote -v";

      # Amend the currently staged files to the latest commit
      amend = "commit --amend --reuse-message=HEAD";

      # Credit an author on the latest commit
      credit = ''"!f() { git commit --amend --author \"$1 <$2>\" -C HEAD; }; f"'';

      squash = ''"!s() { \
          branch=$(git branch --show-current) ;\
          git checkout master; \
          git checkout -b \"$\{branch}-squash\" ; \
          git diff \"master...$branch\" | git apply ; \
          git add . ; \
          git commit "$@" ; \
          git branch -D \"$branch\" ; \
          git checkout -b \"$branch\" ;\
          git branch -D \"$\{branch}-squash\";  }; s"'';

      # Interactive rebase with the given number of latest commits
      reb = ''"!r() { git rebase -i HEAD~$1; }; r"'';

      # Find branches containing commit
      fb = ''"!f() { git branch -a --contains $1; }; f"'';

      # Find tags containing commit
      ft = ''"!f() { git describe --always --contains $1; }; f"'';

      # Find commits by source code
      fc = ''"!f() { git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short -S$1; }; f"'';

      # Find commits by commit message
      fm = ''"!f() { git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short --grep=$1; }; f"'';

      # Remove branches that have already been merged with master
      # a.k.a. ‘delete merged’
      dm = ''"!git branch --merged | grep -v '\\*' | xargs -n 1 git branch -d; git remote -v update -p"'';

      # List contributors with number of commits
      contributors = "shortlog --summary --numbered";

      lg = ''log --color --decorate --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an (%G?)>%Creset' --abbrev-commit'';

      mdiff = ''"!f() { git stash | head -1 | grep -q 'No local changes to save'; x=$?; git merge --no-commit $1 &>/dev/null; git add -u &>/dev/null; git diff --staged; git reset --hard &>/dev/null; test $x -ne 0 && git stash pop &>/dev/null; }; f"'';

      most-edited = ''!git log --format= --name-only | sort | uniq -c | sort -rg | head -20'';

      # from seth vargo https://gist.github.com/sethvargo/6b2f7b592853381690bfe3bd00947e8f
      unreleased = ''"!f() { git fetch --tags && git diff $(git tag | tail -n 1); }; f"'';
      up = ''!git pull origin master && git remote prune origin && git submodule update --init --recursive'';
      undo = ''!git reset HEAD~1 --mixed'';
      top = ''!git log --format=format:%an | sort | uniq -c | sort -r | head -n 20'';

      # from trevor bramble https://twitter.com/TrevorBramble/status/774292970681937920
      alias = ''!git config -l | grep ^alias | cut -c 7- | sort'';

      fresh = "push -o merge_request.label='bot: Keep Fresh ♻'";
      mrc = "push -o merge_request.create -o merge_request.target=master -o merge_request.label='bot: Keep Fresh ♻'";
      mwps = "push -o merge_request.create -o merge_request.target=master -o merge_request.merge_when_pipeline_succeeds  -o merge_request.label='bot: Keep Fresh ♻'";
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.05";
}
