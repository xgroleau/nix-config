{
  description = "My user configuration using home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs ={ self, nixpkgs, home-manager, flake-utils }: 
  let 
    system = "x86_64-linux";
    pkgs = nixpkgs;
  in{
    homeConfigurations = {
      # eachDefaultSystem doesn't work for now.
      xgroleau = home-manager.lib.homeManagerConfiguration {
          inherit system;
          configuration =  ./home.nix;
          homeDirectory = "/home/xgroleau";
          username = "xgroleau";
          stateVersion = "22.05";
      };
    };
  }

    # Set up a "dev shell" that will work on all architectures
  // (flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          nix-zsh-completions
          nixfmt
          home-manager.defaultPackage.${system}
        ];
      };
    }));
}
