# Nix Dotfiles

My declarative dotfiles configuration using [nix](https://nixos.org/) and [home-manager](https://github.com/nix-community/home-manager) to manage my systems.

This configuration **should** work in all distribution in theory, but because nixpkgs has some issue with opengl, some features may not work. Namely `alacritty` and `picom` won't be able to launch if you are not using NixOS.

## Installation

### NixOS

Simply run the command with flakes enabled to get my full NixOS configuration

 ```sh
 nixos-rebuild switch --flake .#<host> -use-remote-sudo
 ```

#### Hosts

||Type|Name|Hardware|Purpose|
|-|-|-|-|-|
|💻|Laptop|WSL|Surface pro 4|Build for WSL for my old surface pro 4.|
|💻|Laptop|Namira|Ideapad Y580, 16GB ram|Super old laptop that I still use on the go|
|🖥️|Desktop|Azura|AMD Ryzen 5 7600, 32GB ram|Main dev machine and gaming rig|
|🎮|Console|Vaermina|Optiplex 3050 | Console for steam remote play and emulators.
|☁️️|Server|Sheogorath|i5-4690K, 32GB ram, 24TB raidz1|Main server for media and services. Previous desktop.|
|☁️|Server|Jyggalag|Oracle A1 free tier, 4 cores, 24GB ram|Mostly to monitor Sheogorath services and trigger alerts.|

### Nix-Darwin

```sh
nix develop
darwin-rebuild switch --flake .#
```


### Home manager

Make sure [flakes are enabled on your system](https://nixos.wiki/wiki/Flakes#Installing_flakes). 

```sh
nix develop
home-manager switch --flake .#<profile>
```

where `<profile>` is your desired profile.

|Name|Description|
|-|-|
|minimal|Minimal TUI headless server|
|dev|Headless development|
|graphical|GUI applications|
|desktop|Full fledge DE and GUI apps|

## Usage as module

You can use this flake as a module to your home-manager configuration or your NixOS configuration.

### NixOS module

To use as a NixOS module

``` nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    nix-dotfiles.url = "github:xgroleau/nix-dotfiles";
  };

  outputs = { nixpkgs, home-manager, nix-dotfiles, ... }: {
    nixosConfigurations = {
      example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nix-dotfiles.nixosModules
          # Enable some modules
          {
            home = {
              enable = true;
              username = "xgroleau";
              profile = "minimal";
            };
          }
        ];
      };
    };
  };
}
```

### Home-Manager module

To use for your home-manager configuration.

``` nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    nix-dotfiles.url = "github:xgroleau/nix-dotfiles";
  };

  outputs = { nixpkgs, home-manager, nix-dotfiles, ... }: {
    homeConfigurations = {
      example = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${flake-utils.lib.system.x86_64-linux};
        modules = [ 
          nix-dotfiles.homeManagerModules
          # Then enable some modules
          {
            # Minimum HM requirements
            home = {
              username = "xgroleau";
              homeDirectory = "/home/xgroleau";
              stateVersion = "23.11";
            };
            modules.shell.zsh.enable = true;
          }
        ];
    };
  };
}
```

## Checks

To check formatting with [nixfmt](https://github.com/NixOS/nixfmt) and analyze with [statix](https://github.com/nerdypepper/statix) you can run

```sh
nix flake check
```

Or to apply the changes directly, you can run.

``` sh
nix run .#fmt
```
