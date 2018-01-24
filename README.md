# What's this?

This repository contains Flutter packages that have been patched for _flutter2js_, which makes Flutter apps run in the browser.

Learn more at [github.com/jban332/flutter2js](https://github.com/jban332/flutter2js),.

# List of packages
## Flutter core
* _dart:ui_ ([original](https://github.com/flutter/engine/tree/master/lib/ui), [docs](https://docs.flutter.io/flutter/dart-ui/dart-ui-library.html))
  * Because Pub doesn't allow overriding "dart:something" packages, it's exposed as "package:flutter/ui.dart".
* _package:flutter_ ([original](https://github.com/flutter/flutter/tree/master/packages/flutter), [docs](https://docs.flutter.io/flutter/flutter/flutter-library.html))
* _package:flutter_localization_ ([original](https://github.com/flutter/flutter/tree/master/packages/flutter), [docs](https://docs.flutter.io/flutter/flutter_localization/flutter_localization-library.html))
* _package:flutter_test_ ([original](https://github.com/flutter/flutter/tree/master/packages/flutter_test), [docs](https://docs.flutter.io/flutter/flutter_test/flutter_test-library.html))

# Description of modifications
## Flutter core
* All of [original flutter packages](https://github.com/flutter/flutter/tree/master/packages/flutter) (January 2018).
* We added a modified version of [dart:ui](https://github.com/flutter/engine/tree/master/lib/ui) from "github.com/flutter/engine". Many classes in _dart:ui_ such as _Canvas_ delegate implementation to Flutter2js or expose
    previously private/external fields.
* Eliminated usage of language features not supported by _dart2js_:
  * Assertions in initializers ([issue #30968](https://github.com/dart-lang/sdk/issues/30968))
  * Some mixins ([issue #23770](https://github.com/dart-lang/sdk/issues/23770))
