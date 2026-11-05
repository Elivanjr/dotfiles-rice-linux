
{ ... }:

{
  programs.zsh = {
    enable = true;

    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    ohMyZsh = {
      enable = true;
      theme = "robbyrussell";

      plugins = [
        "git"
        "sudo"
        "colored-man-pages"
      ];
    };

    shellAliases = {
      ll = "ls -lah";
      la = "ls -A";

    # Reconstrução do sistema
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos#nixos";
      rebuild-test = "sudo nixos-rebuild test --flake ~/nixos#nixos";
      rebuild-boot = "sudo nixos-rebuild boot --flake ~/nixos#nixos";

    # Atualizar os inputs do flake (nixpkgs, home-manager...)
      upd = "nix flake update --flake ~/nixos";

    # Limpeza de gerações antigas e do store
      gc = "sudo nix-collect-garbage -d";

    # Buscar pacotes no nixpkgs
      nxs = "nix search nixpkgs";

    # Ir direto pra config e abrir no editor
      nixcfg = "cd ~/nixos && nvim .";

    # Ver as gerações do sistema
      gens = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
    };

    histSize = 10000;
  };
}

