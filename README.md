# skills

Personal Agent Skills hub built on [agent-skills-nix](https://github.com/Kyure-A/agent-skills-nix).

This flake is a **skills catalog**: it pins skill sources and selects which skills
are enabled. Consumers (NixOS + Home Manager configs) import its Home Manager
module and decide only *whether* to install and *where* (targets).

## Included skills

| Source | Upstream | Selection |
|--------|----------|-----------|
| `caveman` | [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) (`skills/`) | all (22 skills) |
| `anthropic` | [anthropics/skills](https://github.com/anthropics/skills) (`skills/`) | all (19 skills) |

Some Anthropic skills (e.g. `docx`, `pdf`, `pptx`, `xlsx`) are source-available
rather than open source; check each skill's `LICENSE.txt` upstream.

## Repository layout

```text
flake.nix                 # inputs + outputs (HM module, bundle, checks, formatter)
catalog.nix               # sources and skill selection (single source of truth)
modules/home-manager.nix  # maps catalog.nix into programs.agent-skills
```

## Using it on NixOS with Home Manager

These steps assume a flake-based NixOS config with Home Manager running as a
NixOS module (`home-manager.nixosModules.home-manager`).

### 1. Add the flake input

```nix
# flake.nix
inputs = {
  nixpkgs.url = "nixpkgs/nixos-26.05";

  home-manager = {
    url = "github:nix-community/home-manager/release-26.05";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  skills-hub = {
    url = "github:aaryannemade/skills";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

The skill sources (e.g. `caveman`) are inputs of this hub, so you do **not**
add them to your own flake.

### 2. Import the Home Manager module

Pick one of the following.

**a) Shared module for every Home Manager user** (in your NixOS host module):

```nix
outputs = inputs@{ nixpkgs, home-manager, skills-hub, ... }: {
  nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          sharedModules = [ skills-hub.homeManagerModules.default ];
          users.alice = import ./home.nix;
        };
      }
    ];
  };
};
```

**b) Import from inside a Home Manager module** (requires `inputs` in
`home-manager.extraSpecialArgs`):

```nix
# NixOS side
home-manager.extraSpecialArgs = { inherit inputs; };
```

```nix
# some Home Manager module, e.g. modules/ai/opencode.nix
{ inputs, ... }:
{
  imports = [ inputs.skills-hub.homeManagerModules.default ];
}
```

### 3. Enable it and choose targets

The hub sets sources and selection only. Enable the module and at least one
target in your Home Manager config:

```nix
programs.agent-skills = {
  enable = true;
  targets.agents.enable = true;   # $HOME/.agents/skills
};
```

Common global targets:

| Target | Install path | Read by |
|--------|--------------|---------|
| `agents` | `$HOME/.agents/skills` | opencode and other `.agents`-aware tools |
| `opencode` | `$HOME/.config/opencode/skills` | opencode |
| `claude` | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills` | Claude Code **and** opencode |

See the full list in the
[agent-skills-nix installation docs](https://github.com/Kyure-A/agent-skills-nix/blob/master/docs/installation.md#default-target-paths).

> **Avoid duplicates in opencode.** opencode reads `~/.config/opencode/skills`,
> `~/.claude/skills` and `~/.agents/skills`, and requires skill names to be
> unique across all of them. Enable only one of those targets. If you need
> Claude Code too, use `targets.claude` alone; opencode will pick it up.
> Also remove any old `skills.paths` entry in `opencode.json` that points at the
> same skills.

### 4. Lock and rebuild

```sh
nix flake lock --update-input skills-hub   # or: nix flake update skills-hub
sudo nixos-rebuild switch --flake .#myhost
```

On activation, Home Manager syncs the bundle into each enabled target as a
symlink tree. Verify with:

```sh
ls ~/.agents/skills
```

### Existing skill directories

The installer refuses to overwrite a non-empty target directory it does not
own (no `.agent-skills-managed.json` marker). Move or delete the existing
directory before the first switch. See
[destination ownership](https://github.com/Kyure-A/agent-skills-nix/blob/master/docs/installation.md#destination-ownership).

## Customising the selection

Consumers can extend the hub's selection with the same options, because they
merge into the hub's module:

```nix
programs.agent-skills.skills.enable = [ "some-extra-skill" ];
```

To change what the hub ships by default, edit `catalog.nix`.

## Adding a new skill source to the hub

1. Add a non-flake input in `flake.nix`:

   ```nix
   example-skills = {
     url = "github:example-org/example-skills";
     flake = false;
   };
   ```

2. Register it in `catalog.nix`:

   ```nix
   sources.example = {
     path = inputs.example-skills;
     subdir = "skills";   # folder containing <name>/SKILL.md dirs
   };

   # all skills from the source...
   enableAll = [ "caveman" "anthropic" "example" ];
   # ...or individual skills by name
   enable = [ "some-skill" ];
   ```

   Evaluation fails if two sources expose the same skill name; see the
   opencode caveat below before reaching for `idPrefix`.

3. Lock and verify:

   ```sh
   nix flake lock
   nix flake check
   ```

Caveat for opencode: it only discovers `skills/*/SKILL.md` (one level deep),
and the skill `name` must match its directory. Prefixed IDs such as
`anthropic/pdf` install into nested directories (`anthropic/pdf/`), which
opencode will not find. For opencode, skip `idPrefix` and avoid selecting two
skills with the same name. If you must rename one with
`skills.explicit.<name>.rename`, also use `transform` to update the `name:`
field in its `SKILL.md` frontmatter so it matches the new directory.

## Development

```sh
nix flake check                 # builds the selected bundle
nix build .#skills-bundle       # inspect ./result
nix eval .#catalog --json       # every discovered skill
nix fmt                         # nixfmt-tree
nix flake update caveman        # bump a skill source
```

Test changes against a consumer before pushing:

```sh
nix build '.#nixosConfigurations.myhost.config.home-manager.users.alice.home.activationPackage' \
  --override-input skills-hub "git+file://$HOME/Projects/skills"
```
