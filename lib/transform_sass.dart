import 'dart:async';

import 'package:barback/barback.dart' as bb;
import 'package:package_resolver/package_resolver.dart' as pr;
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
    final responses = await Future.wait(
      [this._prepareAssets(transform), this._buildResolver()],
    );

    assets = responses[0] as List<bb.Asset>;
    spr = responses[1] as pr.SyncPackageResolver;

    // For each Sass endpoint (a Sass file without a leading underscore), send
    // build request to the Dart-Sass compiler.
    for (bb.Asset asset in assets) {
      var output = new bb.Asset.fromString(
          asset.id.changeExtension('.css'),
          sass.compile(asset.id.toString().split("|")[1],
              packageResolver: spr));
      transform.addOutput(output);
    }
  }

  /// Read the ".packages" file and build a new [pr.SyncPackageResolver].
  Future<pr.SyncPackageResolver> _buildResolver() async =>
      pr.SyncPackageResolver.loadConfig('.packages');

  // Creates a list of endpoint Sass files (those without leading underscores).
  Future _prepareAssets(bb.AggregateTransform transform) async {
    // Create a starting list of [assets] and an resulting list of endpoint
    // assets, or [rootAssets].
    final assets = await transform.primaryInputs.toList();
    final rootAssets = <bb.Asset>[];

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
