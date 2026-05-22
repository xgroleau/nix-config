{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Adjust based on actual VM hardware. This stub assumes a typical
  # qemu/kvm VM with virtio devices. Run `nixos-generate-config` on the
  # actual VM to get exact values.
  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"
      ];
      kernelModules = [ ];
      # bcachefs needs to be available in initrd for /persist to be mounted
      # before stage-2 (preservation runs in stage-2).
      supportedFilesystems = [ "bcachefs" ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    supportedFilesystems = [ "bcachefs" ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = false;

  # Enable virtio kernel modules for KVM/QEMU virtualization.
  virtualisation.hypervGuest.enable = false;
  services.qemuGuest.enable = true;
}
