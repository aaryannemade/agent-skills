# Catalog half of programs.agent-skills: sources and skill selection only.
# The consumer decides `enable` and which `targets.<name>` to install to.
{ catalog }:
{ ... }:
{
  programs.agent-skills = {
    inherit (catalog) sources;
    skills = {
      inherit (catalog) enable enableAll;
    };
  };
}
