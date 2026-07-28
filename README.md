# swiftui-app-archetype

SwiftUI application with a SwiftPM core, an XcodeGen-generated app shell, and just as the build entry point

## Usage

```sh
archetect render https://github.com/archetect-swift/swiftui-app-archetype.git#v1
```

## Prompts

Document the prompts this archetype asks, the keys they populate, and
where they come from (this archetype or a library dependency).

| Prompt | Key | Source | Notes |
|---|---|---|---|
| _Example prompt_ | `example_key` | _this archetype_ | _Describe._ |

## What it generates

Describe the directory tree your archetype produces.

```
<project_name>/
├── file.ext
└── ...
```

## Testing locally

While iterating on this archetype before cutting a `v1` tag, render
against the local working copy with `--local`:

```sh
archetect render --local https://github.com/archetect-swift/swiftui-app-archetype.git --dest /tmp/out
```

## Release versioning

This archetype comes wired with the
[`archetect-actions/repository-release`](https://github.com/archetect-actions/repository-release)
action. Trigger a `minor_release` via the GitHub Actions tab to cut
`v1.0` and an auto-updating `v1` floating tag.

## Author

Jimmie Fulton <jimmie.fulton@gmail.com>
