# Transform Sass

Transform Sass is a Dart transformer for **pub serve** and **pub build** that
uses [Dart-Sass][https://github.com/sass/dart-sass] for compiling
**scss** and **sass** files into **css**. Transformer supports 'package:...'
imports. This transformer can handle:


* base_project/
  * pubspec.yaml
  * lib/
    * \_base_style.scss
    * more/
      * \_more_base_style.scss
      * \_even_more_base_style.scss

* another_project/
  * pubspec.yaml
  * lib/
    * \_another_style.scss

* your_project/
  * pubspec.yaml
  * lib/
    * \_your_style.scss
  * web/
    * css/
      * style.scss
      * more/
        * \_more_style.scss

Where the contents are as follows:
### All pubspec.yaml files.
```yaml
...
dependencies:
  ...
  transform_sass: '>=0.2.2'

transformers:
  ...
  - transform_sass
...
```

### \_base_style.scss
```scss
@import 'package:base_project/more/more_base_style';
@import 'more/even_more_base_style';
...
```

### \_another_style.scss
```scss
@import 'package:base_project/base_style';
...
```

### \_your_style.scss
```scss
@import 'package:base_project/base_style';
...
```

### style.css
```scss
@import 'more/more_style';
@import 'package:your_project/another_style';
@import 'package:base_project/base_style'; // Redundant, but present for example
...
```

Simply put, all imports work like Dart. To use the transformer, add the
following two lines to your pubspec.yaml file:
```yaml
dependencies:
  transform_sass: '>=0.2.2'
transformers:
  - transform_sass
```
Afterwards, run **pub install**. Changes to the CSS in the browser only require
refreshing the browser when running **pub serve**.

## Links
Source code is available at: https://github.com/halverneus/transform-sass
Pub is available at: https://pub.dartlang.org/packages/transform_sass
