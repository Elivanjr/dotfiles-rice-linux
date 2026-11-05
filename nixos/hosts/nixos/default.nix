{ ... }:

{
  imports = [
    # Sistema
    ../../modules/system/boot.nix
    ../../modules/system/networking.nix
    ../../modules/system/locale.nix
    ../../modules/system/users.nix

    # Desktop
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/polkit.nix

    # Serviços
    ../../modules/services/audio.nix
    ../../modules/services/bluetooth.nix
    ../../modules/services/ollama.nix
    ../../modules/services/printing.nix

    # Programas
    ../../modules/programs/neovim.nix
    ../../modules/programs/zsh.nix

    # Pacotes
    ../../packages
  ];

  system.stateVersion = "26.05";
}

