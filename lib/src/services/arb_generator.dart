import 'dart:convert';
import 'dart:io';

import '../models/arb/arb_file.dart';
import '../models/settings/package_settings.dart';
import 'file_writer/file_writer.dart';
import 'parsing/csv_parser.dart';
import 'validation/validator.dart';

/// A service which generates arb files
abstract class ARBGenerator {
  /// Generates an output arb file
  static void generate(
    PackageSettings packageSettings,
  ) {
    // check that the file exists
    final file = File(packageSettings.inputFilepath);
    Validator.validateFile(file);

    if (!Validator.validateCSVSettings(packageSettings.csvSettings)) {
      exit(0);
    }

    // File is valid, state progress
    print('Loading file ${packageSettings.inputFilepath}...');

    final parser = CSVParser(
      file: file,
      startIndex: packageSettings.csvSettings.baseIndex,
      fieldDelimiter: packageSettings.csvSettings.delimiter,
    );

    final supportedLanguages = parser.supportedLanguages;
    Validator.validateSupportedLanguages(supportedLanguages);

    print('Locales $supportedLanguages determined.');

    final localizationsTable = parser.localizationsTable;
    print('Parsing ${localizationsTable.length} key(s)...');

    final encoder = JsonEncoder.withIndent('  ');

    for (final row in localizationsTable) {
      Validator.validateLocalizationTableRow(
        row,
        numberSupportedLanguages: supportedLanguages.length,
      );
    }

    for (final supportedLanguage in supportedLanguages) {
      final content = _generateARBFile(
        language: supportedLanguage,
        keys: parser.keys,
        values: parser.getValues(supportedLanguage),
        defaultValues: parser.defaultValues,
        descriptions: packageSettings.csvSettings.descriptionIndex != null
            ? parser.getColumn(packageSettings.csvSettings.descriptionIndex!)
            : null,
      );
      var prettyContent = encoder.convert(content.toJson());
      // convert turns \n into \\n
      prettyContent = prettyContent.replaceAll('\\\\', '\\');

      // write output file
      final path =
          '${packageSettings.outputDirectory}/${packageSettings.filenamePrepend}$supportedLanguage.arb';
      FileWriter().write(
        contents: prettyContent,
        path: path,
      );

      print('Generated $path');
    }

    print('All done!');
  }
}

ARBFile _generateARBFile({
  required String language,
  required List<String> keys,
  required List<String> values,
  required List<String> defaultValues,
  List<String>? descriptions,
}) {
  if (keys.length != values.length && keys.length != defaultValues.length) {
    print('Error! Mismatch number of keys and values');
    exit(0);
  }

  final messages = <Message>[];
  for (var i = 0; i < keys.length; i++) {
    final value = i < values.length && values[i].isNotEmpty
        ? values[i]
        : defaultValues[i];
    messages.add(Message(
      key: keys[i],
      value: value,
      description: descriptions?[i],
    ));
  }

  return ARBFile(locale: language, messages: messages);
}
