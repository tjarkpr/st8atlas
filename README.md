# st8atlas

> st8atlas: Where IaC comes alive

st8atlas is a small Bash CLI that scaffolds and drives [Terragrunt](https://terragrunt.gruntwork.io/)
projects. It keeps an explicit inventory of your **stacks** and **units** in an `atlas.st8` file and
generates the matching Terragrunt and Terraform files for you.

## Requirements

- `bash` 4.4 or newer
- `terraform` and `terragrunt` on your `PATH` (checked before every command)
- `curl` or `wget` and `tar` for the installer

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/tjarkpr/st8atlas/main/install.sh | bash
```

The installer downloads a GitHub release, unpacks it to `~/.local/share/st8atlas` and links
`st8atlas` into `~/.local/bin`. If that directory is not on your `PATH`, it is appended to your
shell profile.

| Option | Description |
| --- | --- |
| `--version <tag>` | Install a specific release instead of the latest |
| `--install-dir <dir>` | Where the sources are unpacked |
| `--bin-dir <dir>` | Where the `st8atlas` launcher is linked |
| `--with <a,b>` | Optional extensions to install |
| `--with-all` | Install every available extension |
| `--no-profile` | Do not modify your shell profile |
| `--uninstall` | Remove a previous installation |

```bash
# Pin a version and keep the profile untouched
./install.sh --version v1.2.0 --no-profile

# Install with both extensions
./install.sh --with diagram,cost

# Remove it again
./install.sh --uninstall
```

## Project layout

Every command except `init` must run from a directory that contains an `atlas.st8` file.

```
my-project/
├── atlas.st8          # inventory of stacks and units
├── .gitignore
├── stacks/
│   ├── root.hcl               # shared Terragrunt root
│   └── shared/
│       ├── root.hcl           # inherits the level above
│       └── platform/
│           ├── terragrunt.stack.hcl
│           └── stack.st8      # snapshot used by 'stack diff'
├── units/
│   └── storage/
│       └── terragrunt.hcl
└── modules/
    └── storage/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

- **stacks** are explicit `terragrunt.stack.hcl` files. A `root.hcl` is generated at every level from
  `stacks/` down to the parent of the stack, each one inheriting the level above. The stack file
  itself pulls in the nearest root, so the whole chain applies.
- **units** always map one to one to a Terraform module. `unit add` creates both.
- All generated content is placeholder content for now.

## Usage

```bash
st8atlas <command> [args...]
```

Run `st8atlas <command> --help` for the full argument list.

### init

```bash
st8atlas init [--path <dir>] [--force]
```

Creates `atlas.st8`, `.gitignore` and the `stacks/`, `units/` and `modules/` directories.

### stack

| Capability | Description |
| --- | --- |
| `add` | Create a stack. Prompts for the units to include |
| `units` | Reopen the unit selection for an existing stack |
| `list` | List stacks with the number of units they use |
| `remove` | Delete a stack and its directory |
| `snapshot` | Write the `stack.st8` snapshot of a stack |
| `diff` | Compare a stack against a `stack.st8` snapshot |
| `sync` | Reconcile the inventory with the files on disk |
| `init`, `plan`, `apply`, `destroy`, `validate` | Run the matching Terragrunt command |
| `format` | Run `terragrunt hclfmt` |

```bash
st8atlas stack add --name platform --path shared/platform --description "Shared platform"
st8atlas stack units --name platform --units storage,database
st8atlas stack apply --name platform
```

`add` and `units` show an interactive checkbox list of the available units. Pass `--units a,b` to
skip the prompt or `--no-interactive` to never prompt. The prompt is also skipped automatically when
the command does not run on a terminal.

> `stack units` regenerates `terragrunt.stack.hcl` from the template, so manual edits to that file
> are lost.

### Snapshots and diffs

Every stack carries a `stack.st8` snapshot, refreshed whenever the stack is created or its units
change, and on demand with `stack snapshot`. It is a plain text file with a pipe separated header and
`[section]` blocks:

```
version|1
stack|platform
path|stacks/shared/platform

[units]
database
storage

[dependencies]
storage|database

[diagram]
digraph "platform" { ... }

[cost]
{ "stack": "platform", "units": [ ... ] }
```

The `[units]` and `[dependencies]` sections always exist. `[diagram]` and `[cost]` are contributed by
the extensions through the `snapshot` hook, so a snapshot only carries what is actually installed.
The diagram is stored as raw DOT, which means graphviz is not needed to take a snapshot. The cost
section is JSON so it stays machine readable; the markdown rendering is what `cost report` is for.

`stack diff` compares the current state against a snapshot taken earlier and writes a markdown
report:

```bash
st8atlas stack snapshot --name platform
cp stacks/shared/platform/stack.st8 baseline.st8

# ...change things...

st8atlas stack diff --name platform --baseline baseline.st8
st8atlas stack diff --name platform --baseline baseline.st8 --output report.md
```

The report contains a summary table, per-unit and per-dependency change tables, and the raw diagram
and cost breakdown of both sides in collapsible blocks.

### unit

| Capability | Description |
| --- | --- |
| `add` | Create a unit and its Terraform module |
| `list` | List units with the number of stacks referencing them |
| `remove` | Delete a unit and its module |
| `sync` | Reconcile the inventory with the files on disk |
| `validate` | Run `terragrunt validate` |
| `format` | Run `terragrunt hclfmt` and `terraform fmt` |

```bash
st8atlas unit add --name storage --description "Storage unit"
st8atlas unit remove --name storage           # refused while a stack uses it
st8atlas unit remove --name storage --force   # removes it anyway
```

Removing a unit that is still referenced by a stack fails. `--force` overrides this and warns about
the dangling references it leaves behind.

## Extensions

Extensions are optional and ship with every release, but are only active when installed with
`--with` or `--with-all`. They appear as additional commands under `Extensions:` in the help output.

### diagram

Renders a stack, its units and their modules as a PNG. Requires [graphviz](https://graphviz.org/).

```bash
st8atlas diagram --name platform                  # writes diagram.png into the stack
st8atlas diagram --name platform --path out.png   # writes somewhere else
```

Dependencies between units are included. Both `dependency "name" { config_path = ... }` and
`dependencies { paths = [...] }` blocks in a unit's `terragrunt.hcl` are drawn as labelled edges.
Targets that are not part of the stack are shown as dashed nodes marked *outside the stack*.

### cost

Generates cost estimates with `c3x`. While this extension is installed, every new stack
automatically gets a `c3x-usage.yml` usage configuration, and every stack snapshot carries a `[cost]`
section as JSON.

```bash
st8atlas cost report --name platform                    # markdown to stdout
st8atlas cost report --name platform --output cost.md   # markdown to a file
st8atlas cost sync                                      # add the usage config where it is missing
```

`cost report` produces structured markdown: an overview table of the stack's units and their modules,
followed by one section per unit with the `c3x estimate --format markdown` breakdown. It runs against
the Terraform module behind every unit, since `c3x` reads Terraform rather than Terragrunt. Use
`cost sync` after installing the extension to backfill stacks that were created earlier.

## Output

Colors are enabled on terminals and disabled automatically when the output is piped or when
`NO_COLOR` is set.

## Development

```bash
bash test/smoke.sh
```

The smoke test stubs `terraform`, `terragrunt`, `c3x` and `dot`, then exercises every command against
a throwaway project in a temporary directory, once without and once with the extensions.

Running `src/st8atlas.sh` directly loads every extension in `src/extensions`. Set
`ST8ATLAS_EXTENSIONS_DIR` to another directory to control which ones are active.

## License

See [LICENSE](LICENSE).
