{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  keys = import ../../secrets/ssh-keys.nix;
in
{
  imports = [
    # The minimal ISO profile from nixpkgs. Provides everything needed to
    # produce a bootable installer ISO via:
    #   nix build .#nixosConfigurations.installer.config.system.build.isoImage
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")

    # The netboot profile adds `system.build.kexecTree` (kernel + initrd +
    # nixos-kexec.tar.gz) so we can also produce a kexec image for
    # nixos-anywhere's --kexec flag:
    #   nix build .#nixosConfigurations.installer.config.system.build.kexecTree
    (modulesPath + "/installer/netboot/netboot.nix")
  ];

  # Bcachefs support — the whole reason this installer exists. We need it
  # in the running kernel AND the userspace tools, AND we need the module
  # available in the initrd in case we ever pivot-root onto bcachefs.
  #
  # The installation-cd-minimal profile pulls in ZFS by default; we disable
  # it because (a) we don't need it here and (b) ZFS-on-latest-kernel is
  # frequently broken on unstable.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = {
      bcachefs = true;
      zfs = lib.mkForce false;
    };
    initrd.supportedFilesystems = [ "bcachefs" ];
  };

  environment.systemPackages = with pkgs; [
    bcachefs-tools
    git
    vim
    # Useful for nixos-install / disko / nixos-anywhere workflows.
    parted
    cryptsetup
  ];

  # SSH in by default so you can drive the install from your workstation
  # (manual installs OR nixos-anywhere). The ISO defaults to "nixos" with
  # no password; we authorize your key explicitly.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    keys.users.xgroleau
  ];

  # Don't gate ISO build on stable-version checks (the ISO is throwaway).
  system.stateVersion = "25.11";
}
