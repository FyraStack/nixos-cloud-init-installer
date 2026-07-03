{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    "${modulesPath}/virtualisation/proxmox-image.nix"
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = config.system.nixos.release;

  proxmox = {
    partitionTableType = "efi";
    qemuConf = {
      name = "nixos-cloud";
      bios = "ovmf";
      boot = "order=virtio0";
      scsihw = "virtio-scsi-single";
      ostype = "l26";
      agent = true;
      serial0 = "socket";
      net0 = "virtio=00:00:00:00:00:00,bridge=vmbr0,firewall=1";
    };
    cloudInit = {
      enable = true;
      defaultStorage = "local-lvm";
      device = "ide2";
    };
  };

  virtualisation.diskSize = 4096;

  boot = {
    loader.timeout = lib.mkForce 0;
    kernelParams = [
      "console=ttyS0,115200n8"
      "console=tty1"
    ];
    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "virtio_net"
      "nvme"
      "xhci_pci"
    ];
  };

  networking = {
    usePredictableInterfaceNames = false;
    useNetworkd = true;
    useDHCP = false;
    dhcpcd.enable = false;
  };

  services = {
    cloud-init = {
      enable = true;
      network.enable = true;
      settings = {
        datasource_list = [ "NoCloud" ];
        disable_root = false;
        ssh_pwauth = true;
        chpasswd.expire = false;
      };
    };

    openssh = {
      enable = true;
      settings = {
        Include = "/etc/ssh/sshd_config.d/*.conf";
        PasswordAuthentication = lib.mkDefault true;
      };
    };

    qemuGuest.enable = true;
  };

  security.sudo.wheelNeedsPassword = false;

  systemd.tmpfiles.rules = [
    "d /etc/ssh/sshd_config.d 0755 root root -"
  ];

  environment.systemPackages = with pkgs; [
    cloud-init
    curl
    nano
    vim
  ];
}
