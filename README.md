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
| `--no-profile` | Do not modify your shell profile |
| `--uninstall` | Remove a previous installation |

```bash
# Pin a version and keep the profile untouched
./install.sh --version v1.2.0 --no-profile

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
│           └── terragrunt.stack.hcl
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

## Output

Colors are enabled on terminals and disabled automatically when the output is piped or when
`NO_COLOR` is set.

## Development

```bash
bash test/smoke.sh
```

The smoke test stubs `terraform` and `terragrunt`, then exercises every command against a throwaway
project in a temporary directory.

## License

See [LICENSE](LICENSE).
