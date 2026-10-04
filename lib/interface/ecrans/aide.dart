import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/configuration.dart';
import '../../config/theme.dart';
import '../composants/elements.dart';

/// Présentation du produit, mode d'emploi, support et version.
class EcranAide extends StatelessWidget {
  const EcranAide({super.key, required this.version});

  final String version;

  Future<void> _copierContact(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: Configuration.contactSupport),
    );
    if (context.mounted) afficherMessage(context, 'Adresse du support copiée.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide et support'),
        backgroundColor: Couleurs.fond,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: Couleurs.degrade,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resto Connect · Terminal',
                  style: TextStyle(
                    color: Couleurs.vertClair,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Le contrôle des repas au comptoir, en une seconde.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Fonctionne même sans Internet · Version $version',
                  style: TextStyle(color: Colors.white.withValues(alpha: .8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Carte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode d\'emploi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 14),
                _Etape(
                  numero: 1,
                  titre: 'Mettez à jour',
                  texte:
                      'Avant le service, touchez « Rechercher les mises à jour ».',
                ),
                _Etape(
                  numero: 2,
                  titre: 'Scannez',
                  texte:
                      'Démarrez le service et présentez la carte devant la caméra.',
                ),
                _Etape(
                  numero: 3,
                  titre: 'Validez',
                  texte:
                      'Vérifiez la photo, puis touchez « Valider le repas ».',
                ),
                _Etape(
                  numero: 4,
                  titre: 'Terminez',
                  texte: 'En fin de service, touchez « Terminer le service ».',
                ),
                SizedBox(height: 6),
                Bandeau(
                  texte:
                      'Écran vert et bip aigu : repas validé. Écran rouge et bip grave : accès refusé, le motif s\'affiche.',
                  icone: Icons.info_outline_rounded,
                  alerte: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Carte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Support',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Notre équipe vous répond par e-mail. Précisez la version utilisée et, si possible, joignez une capture d\'écran.',
                  style: TextStyle(color: Couleurs.discret, height: 1.4),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _copierContact(context),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text(Configuration.contactSupport),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Resto Connect · Version $version\n© ${DateTime.now().year} Resto Connect. Tous droits réservés.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Couleurs.discret, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  const _Etape({
    required this.numero,
    required this.titre,
    required this.texte,
  });

  final int numero;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: Couleurs.vertFonce,
          child: Text(
            '$numero',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                texte,
                style: const TextStyle(color: Couleurs.discret, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
