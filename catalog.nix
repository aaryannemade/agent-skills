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

    # No idPrefix: opencode only discovers skills/*/SKILL.md, and prefixed
    # IDs would install into nested directories. Names don't collide with
    # caveman's.
    anthropic = {
      path = inputs.anthropic-skills;
      subdir = "skills";
    };
  };

  # Source names whose discovered skills are all enabled.
  enableAll = [
    "caveman"
    "anthropic"
  ];

  # Individual skill IDs to enable (from any source).
  enable = [ ];
}
