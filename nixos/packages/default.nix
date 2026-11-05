
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Navegador e comunicação
    brave
    discord
    spotify

    # Terminal e utilitários
    kitty
    fastfetch
    git
    wget
    curl
    unzip
    zip
    p7zip
    unrar

    # Captura e ferramentas Wayland
    grim
    wl-clipboard
    waypaper
    swww
    awww
    hyprpicker
    wev
    evtest

    # Multimídia
    playerctl
    pavucontrol
    mpv
    atril
    qview

    # Desenvolvimento e pesquisa
    ripgrep
    fd
    gcc
    tree-sitter

    # Interface e configuração
    networkmanagerapplet
    quickshell
    qt6.qtwayland
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}

