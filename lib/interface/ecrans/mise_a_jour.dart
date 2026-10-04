import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../domaine/texte.dart';
import '../../etat/etat_terminal.dart';
import '../composants/elements.dart';

/// Le serveur exige une version plus récente : l'application doit être mise à jour.
/// Les scans en attente restent dans la base locale et seront envoyés après la mise à jour.
class EcranMiseAJour extends StatelessWidget {
  const EcranMiseAJour({super.key, required this.etat});

  final EtatTerminal etat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Carte(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: Couleurs.vertPale,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      size: 48,
                      color: Couleurs.vert,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Mise à jour requise',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cette version de l\'application (${etat.version}) n\'est plus acceptée. '
                    'Demandez au gérant d\'installer la nouvelle version (${etat.versionMinimale} ou plus).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Couleurs.discret,
                      height: 1.4,
                    ),
                  ),
                  if (etat.enAttente > 0) ...[
                    const SizedBox(height: 16),
                    Bandeau(
                      texte:
                          '${nombre(etat.enAttente, 'repas', 'repas')} en attente : ils sont gardés '
                          'et seront envoyés après la mise à jour.',
                      alerte: false,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
