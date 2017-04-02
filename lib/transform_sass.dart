import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:barback/barback.dart' as bb;
import 'package:package_resolver/package_resolver.dart' as pr;
import 'package:path/path.dart' as p;
import 'package:sass/sass.dart' as sass;

/// Uses the [Dart-Sass][https://github.com/dart-league/dart-sass] compiler to
/// convert **scss** and **sass** files into **css** via **pub serve** and
/// **pub build**. In addition to other available transformers, this works for
/// **package:** files from imports, as well as those in the project's "lib/"
/// and "web/" folders.
///
/// This does break the transformer requirement of not reading from the file
/// system. A future alternative may be to create a temporary directory.
class TransformSass extends bb.AggregateTransformer {
  /// Required to identify [TransformSass] as a transformer.
  TransformSass.asPlugin();

  /// Returns null if the [id] isn't a target **scss** or **sass** file. All
  /// **scss** and **sass** files are potential modifiers of the final **css**.
  String classifyPrimary(bb.AssetId id) {
    if (id.extension != '.scss' && id.extension != '.sass') return null;
    return "these";
  }

  /// Perform the actual transformation based on the contents of the ".packages"
  /// file.
  Future apply(bb.AggregateTransform transform) async {
    // Retrieve resource inputs and ".packages" file contents asynchronously.
    // Wait for both to finish before continuing.

    // Retrieve a filtered list of assets that do not contain a leading
    // underscore. Open the ".packages" file and build a resolver for the Sass
    // compiler. Wait for both processes to complete before continuing.
    List<bb.Asset> assets;
    pr.SyncPackageResolver spr;
    await Future.wait(
      [this._prepareAssets(transform), this._buildResolver()],
    ).then((List responses) {
      assets = responses[0] as List<bb.Asset>;
      spr = responses[1] as pr.SyncPackageResolver;
    });

    // For each Sass endpoint (a Sass file without a leading underscore), send
    // build request to the Dart-Sass compiler.
    for (bb.Asset asset in assets) {
      var output = new bb.Asset.fromString(asset.id.changeExtension('.css'),
          sass.render(asset.id.toString().split("|")[1], packageResolver: spr));
      transform.addOutput(output);
    }
  }

  /// Read the ".packages" file and build a new [pr.SyncPackageResolver].
  pr.SyncPackageResolver _buildResolver() async {
    // Read all contents from the ".packages" file and divide into rows.
    var file = new File(".packages");
    String contents = await file.readAsString(encoding: ASCII);
    var rows = contents.split("\n");
    // 'resolver' is used to construct a new SyncPackageResolver after being
    // populated.
    Map<String, Uri> resolver = new Map<String, Uri>();
    // Evaluate each row in the file. Content appears as:
    // "library:file:///home/user/.pub-cache/hosted/.../lib/"
    // **or**
    // "project:lib/"
    for (String row in rows) {
      // Confirm row should be evaluated.
      if (!row.contains("#") && row.contains(":")) {
        // ["library","file","///home/user/.pub-cache/hosted/.../lib/"]
        // **or**
        // ["project", "lib/"]
        var parts = row.split(":");
        // "library"
        // **or**
        // "project"
        String key = parts[0];
        // "file:///home/user/.pub-cache/hosted/.../lib/"
        // **or**
        // "lib/"
        String value = parts.getRange(1, parts.length).join(":");
        if ("lib/" == value) {
          var dir = new Directory(file.absolute.path);
          // "/home/user/dart_projects/project/lib/"
          value = dir.parent.absolute.path + "/lib/";
        }
        var uri = new Uri.file(value.replaceFirst("file://", ""));
        // "library" : "/home/user/.pub-cache/hosted/.../lib/"
        // **or**
        // "project" : "/home/user/dart-projects/project/lib/"
        resolver[key] = uri;
      }
    }
    return new pr.SyncPackageResolver.config(resolver);
  }

  // Creates a list of endpoint Sass files (those without leading underscores).
  List<Asset> _prepareAssets(bb.AggregateTransform transform) async {
    // Create a starting list of [assets] and an resulting list of endpoint
    // assets, or [rootAssets].
    List<bb.Asset> assets = await transform.primaryInputs.toList();
    List<bb.Asset> rootAssets = [];

    // This is a filter for **sass* and **scss* file names with a leading
    // underscore. Changes "PROJ|path/to/_file.scss" into "_file.scss" and looks
    // for the leading underscore, rejecting all that possess it.
    for (bb.Asset asset in assets) {
      // "my.scss" = "library|folder/my.scss"
      String filename =
          new Uri.file(asset.id.toString().split("|")[1]).pathSegments.last;
      // Add endpoint Sass files.
      if (!filename.startsWith("_")) {
        rootAssets.add(asset);
      }
    }
    return rootAssets;
  }
}
