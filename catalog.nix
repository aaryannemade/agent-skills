# Single source of truth for the hub: which skill sources exist and which
# skills are selected. Consumed by both the Home Manager module and the
# standalone bundle/check outputs in flake.nix.
{ inputs }:
{
  sources = {
    caveman = {
      path = inputs.caveman;
      subdir = "skills";
    };
  };

  # Source names whose discovered skills are all enabled.
  enableAll = [ "caveman" ];

  # Individual skill IDs to enable (from any source).
  enable = [ ];
}
