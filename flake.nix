{
  description = "Personal agent skills hub (agent-skills-nix catalog)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    agent-skills = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caveman = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
    };

    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

    playwright-skill = {
      url = "github:lackeyjb/playwright-skill";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      agent-skills,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;

      catalog = import ./catalog.nix { inherit inputs; };
      agentLib = agent-skills.lib.agent-skills;

      discovered = agentLib.discoverCatalog catalog.sources;
      selection = agentLib.selectSkills {
        catalog = discovered;
        inherit (catalog) sources;
        allowlist = agentLib.allowlistFor {
          catalog = discovered;
          inherit (catalog) sources enable enableAll;
        };
        skills = { };
      };

      bundleFor =
        system:
        agentLib.mkBundle {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit selection;
        };
    in
    {
      homeManagerModules.default = {
        imports = [
          agent-skills.homeManagerModules.default
          (import ./modules/home-manager.nix { inherit catalog; })
        ];
      };

      # JSON-ready view of every discovered skill (selected or not).
      catalog = agentLib.catalogJson discovered;

      packages = forAllSystems (system: rec {
        skills-bundle = bundleFor system;
        default = skills-bundle;
      });

      checks = forAllSystems (system: {
        skills-bundle = bundleFor system;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
