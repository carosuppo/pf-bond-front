import 'dart:io';

const String _productionBaseUrl = 'https://srv2008002.hstgr.cloud';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || !{'run', 'build'}.contains(arguments.first)) {
    stderr.writeln(
      'Uso: dart run tool/flutter_with_env.dart <run|build> [opciones de Flutter]',
    );
    exitCode = 64;
    return;
  }

  final environmentFile = File('.env');
  if (!environmentFile.existsSync()) {
    stderr.writeln('No se encontró el archivo .env local.');
    exitCode = 1;
    return;
  }

  final values = _readEnvironment(environmentFile);
  final apiBaseUrl = values['API_BASE_URL']?.trim() ?? '';
  final cartoApiKey = values['CARTO_API_KEY']?.trim() ?? '';
  final releaseBuild = _isReleaseBuild(arguments);

  try {
    if (releaseBuild) {
      if (apiBaseUrl != _productionBaseUrl) {
        throw StateError(
          'API_BASE_URL debe ser $_productionBaseUrl para compilar en release.',
        );
      }
      if (cartoApiKey.isEmpty) {
        throw StateError(
          'CARTO_API_KEY es obligatorio para compilar en release.',
        );
      }
    } else {
      _validateDevelopmentBaseUrl(apiBaseUrl);
    }

    final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final process = await Process.start(
      executable,
      [
        ...arguments,
        '--dart-define=API_BASE_URL=$apiBaseUrl',
        '--dart-define=CARTO_API_KEY=$cartoApiKey',
      ],
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on ProcessException {
    stderr.writeln('No se pudo iniciar Flutter desde el PATH.');
    exitCode = 1;
  }
}

Map<String, String> _readEnvironment(File file) {
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) continue;

    final separatorIndex = trimmedLine.indexOf('=');
    if (separatorIndex <= 0) continue;

    final key = trimmedLine.substring(0, separatorIndex).trim();
    if (key != 'API_BASE_URL' && key != 'CARTO_API_KEY') continue;

    var value = trimmedLine.substring(separatorIndex + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return values;
}

bool _isReleaseBuild(List<String> arguments) {
  if (arguments.contains('--release')) return true;
  return arguments.first == 'build' &&
      !arguments.contains('--debug') &&
      !arguments.contains('--profile');
}

void _validateDevelopmentBaseUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw StateError('API_BASE_URL debe ser una URL HTTP o HTTPS válida.');
  }
}
