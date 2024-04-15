# Contributing to the Maplibre Navigation SDK for iOS

## Reporting an issue

Bug reports and feature requests are more than welcome, but please consider the following tips so we can respond to your feedback more effectively.

Before reporting a bug here, please determine whether the issue lies with the navigation SDK itself or with another Maplibre/Mapbox product:

When reporting a bug in the navigation SDK itself, please indicate:

* The navigation SDK version
* Whether you installed the SDK using Carthage or manual
* The iOS version, iPhone model, and Xcode version, as applicable
* Any relevant language settings

## Building the SDK

To build this SDK, you need Xcode 15. Simply open Package.swift, it will open in Xcode and download all required dependencies.

## Enable automatic code formatting

We use SwiftFormat via a commit hook which allows us to reformat the changed files on commit. This ensures a conistent code style. The repo is prepared for this, however you need to enable this manually via:

```bash
git config core.hooksPath .githooks
```

## Testing the SDK

You can run tests locally in Xcode. As a safety measure tests are run via GitHub Actions when you submitt a PR. If you are a first time contributor a member of maplibre needs to approve the GitHub Actions runs first, for this please tag someone either in GitHub or in the OpenStreetMap Slack.

## Opening a pull request

Pull requests are appreciated. If your PR includes any changes that would impact developers or end users, please mention those changes in the “main” section of [CHANGELOG.md](CHANGELOG.md), noting the PR number. Examples of noteworthy changes include new features, fixes for user-visible bugs, renamed or deleted public symbols, and changes that affect bridging to Objective-C.

## Making any symbol public

To add any type, constant, or member to the SDK’s public interface:

1. Ensure that the symbol bridges to Objective-C and does not rely on any language features specific to Swift – so no namespaced types or classes named with emoji! 🙃
1. Name the symbol according to [Swift design guidelines](https://swift.org/documentation/api-design-guidelines/) and [Cocoa naming conventions](https://developer.apple.com/library/prerelease/content/documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html#//apple_ref/doc/uid/10000146i).
1. Use `@objc(…)` to specify an Objective-C-specific name that conforms to Objective-C naming conventions. Use the `MB` class prefix to avoid conflicts with client code.
1. Provide full documentation comments. We use [jazzy](https://github.com/realm/jazzy/) to produce the documentation found [on the website for this SDK](http://mapbox.com/mapbox-navigation-ios/navigation/). Many developers also rely on Xcode’s Quick Help feature, which supports a subset of Markdown.
1. __(Optional.)__ Add the type or constant’s name to the relevant category in the `custom_categories` section of [the jazzy configuration file](./docs/jazzy.yml). This is required for classes and protocols and also recommended for any other type that is strongly associated with a particular class or protocol. If you leave out this step, the symbol will appear in an “Other” section in the generated HTML documentation’s table of contents.

## Adding user-facing text

To add or update text that the user may see in the navigation SDK:

1. Use the `NSLocalizedString(_:tableName:bundle:value:comment:)` method:

```swift

NSLocalizedString("UNIQUE_IDENTIFIER", bundle: .mapboxNavigation, value: "What English speakers see", comment: "Where this text appears or how it is used")

```

1. __(Optional.)__ If you need to embed some text in a string, use `NSLocalizedString(_:tableName:bundle:value:comment:)` with `String.localizedStringWithFormat(_:_:)` instead of `String(format:)`:

```swift

String.localizedStringWithFormat(NSLocalizedString("UNIQUE_IDENTIFIER", bundle: .mapboxNavigation, value: "What English speakers see with %@ for each embedded string", comment: "Format string for a string with an embedded string; 1 = the first embedded string"), embeddedString)

```

1. __(Optional.)__ When dealing with a number followed by a pluralized word, do not split the string. Instead, use a format string and make `val` ambiguous, like `%d file(s)`. Then pluralize for English in the appropriate [.stringsdict file](https://developer.apple.com/library/ios/documentation/MacOSX/Conceptual/BPInternational/StringsdictFileFormat/StringsdictFileFormat.html). See [MapboxNavigation/Resources/en.lproj/Localizable.stringsdict](MapboxNavigation/Resources/en.lproj/Localizable.stringsdict) for an example. Localizers should do likewise for their languages.
1. Run `scripts/extract_localizable.sh` to add the new text to the .strings files.
1. Open a pull request with your changes. Once the pull request is merged, Transifex will pick up the changes within a few hours.

## Adding or updating a localization

The Mapbox Navigation SDK for iOS features several translations contributed through [Transifex](https://www.transifex.com/mapbox/mapbox-navigation-ios/). If your language already has a translation, feel free to complete or proofread it. Otherwise, please [request your language](https://www.transifex.com/mapbox/mapbox-navigation-ios/) so you can start translating. Note that we’re primarily interested in languages that iOS supports as system languages.

Once you’ve finished translating the iOS navigation SDK into a new language in Transifex, open an issue in this repository asking to pull in your localization. Or do it yourself and open a pull request with the results:

1. __(First time only.)__ Download the [`tx` command line tool](https://docs.transifex.com/client/installing-the-client) and [configure your .transifexrc](https://docs.transifex.com/client/client-configuration).
1. In MapboxNavigation.xcodeproj, open the project editor. Using the project editor’s sidebar or tab bar dropdown, go to the “MapboxNavigation” project. Under the Localizations section of the Info tab, click the + button to add your language to the project.
1. In the sheet that appears, select all the files, then click Finish.

The .strings files should still be in the original English – that’s expected. Now you can pull your translations into this repository:

1. Run `tx pull -a` to fetch translations from Transifex. You can restrict the operation to just the new language using `tx pull -l xyz`, where __xyz__ is the language code.
2. To facilitate diffing and merging, convert any added .strings files from UTF-16 encoding to UTF-8 encoding. You can convert the file encoding using Xcode’s File inspector or by running `scripts/convert_string_files.sh`.
3. For each of the localizable files in the project, open the file, then, in the File inspector, check the box for your new localization.

## Setup for creating pull requests

- Fork this project
- In your fork, create a branch, for example: `fix/camera-update`
- Add your changes
- Push and open a PR with your branch
