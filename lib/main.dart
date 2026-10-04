import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'donnees/base_locale.dart';
import 'donnees/client_api.dart';
import 'donnees/depot.dart';
import 'etat/etat_terminal.dart';
import 'interface/sons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Terminal fixé au comptoir : affichage en portrait uniquement.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final version = (await PackageInfo.fromPlatform()).version;
  final etat = EtatTerminal(
    depot: Depot(await ouvrirBaseLocale()),
    api: ClientApi(version: version),
  );
  final sons = Sons();

  runApp(ApplicationTerminal(etat: etat, sons: sons));
  await sons.preparer();
  await etat.demarrer();
}
