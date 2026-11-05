
{ ... }:

{
  users.users.biscoito = {
    isNormalUser = true;
    description = "Biscoito";

    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
}

