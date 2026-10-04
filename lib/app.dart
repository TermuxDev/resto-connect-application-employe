import 'package:flutter/material.dart';

import 'config/theme.dart';
import 'etat/etat_terminal.dart';
import 'interface/ecrans/accueil.dart';
import 'interface/ecrans/connexion.dart';
import 'interface/ecrans/mise_a_jour.dart';
import 'interface/ecrans/service.dart';
import 'interface/sons.dart';

/// L'écran affiché découle uniquement de la phase de l'état : pas de navigation à gérer à la main.
class ApplicationTerminal extends StatelessWidget {
  const ApplicationTerminal({
    super.key,
    required this.etat,
    required this.sons,
  });

  final EtatTerminal etat;
  final Sons sons;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resto Connect · Terminal',
      debugShowCheckedModeBanner: false,
      theme: themeResto(),
      home: ListenableBuilder(
        listenable: etat,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (etat.phase) {
            Phase.demarrage => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            Phase.connexion => EcranConnexion(etat: etat),
            Phase.miseAJourRequise => EcranMiseAJour(etat: etat),
            Phase.accueil => EcranAccueil(etat: etat),
            Phase.service => EcranService(etat: etat, sons: sons),
          },
        ),
      ),
    );
  }
}
