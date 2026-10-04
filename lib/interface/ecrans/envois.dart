import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../domaine/modeles.dart';
import '../../domaine/texte.dart';
import '../../etat/etat_terminal.dart';
import '../composants/elements.dart';

/// Repas en attente d'envoi et historique des envois au serveur.
class EcranEnvois extends StatefulWidget {
  const EcranEnvois({super.key, required this.etat});

  final EtatTerminal etat;

  @override
  State<EcranEnvois> createState() => _EcranEnvoisState();
}

class _EcranEnvoisState extends State<EcranEnvois> {
  late Future<(List<RepasEnAttente>, List<Synchronisation>)> _donnees =
      _charger();

  Future<(List<RepasEnAttente>, List<Synchronisation>)> _charger() async => (
    await widget.etat.repasEnAttente(),
    await widget.etat.historiqueDesEnvois(),
  );

  Future<void> _envoyer() async {
    final message = await widget.etat.rechercherMisesAJour();
    if (!mounted) return;
    afficherMessage(context, message);
    setState(() => _donnees = _charger());
  }

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Envois'),
        backgroundColor: Couleurs.fond,
      ),
      body: FutureBuilder(
        future: _donnees,
        builder: (context, instantane) {
          if (!instantane.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (enAttente, historique) = instantane.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              ListenableBuilder(
                listenable: etat,
                builder: (context, _) => FilledButton.icon(
                  onPressed: etat.occupe ? null : _envoyer,
                  icon: etat.occupe
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(
                    etat.occupe ? 'Envoi en cours…' : 'Envoyer maintenant',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Les repas validés sont gardés sur ce téléphone jusqu\'à leur envoi : '
                'une coupure de réseau ne fait rien perdre.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Couleurs.discret, fontSize: 13),
              ),

              _Titre('En attente d\'envoi', enAttente.length),
              if (enAttente.isEmpty)
                const Bandeau(
                  texte: 'Tout est envoyé : aucun repas en attente.',
                  icone: Icons.cloud_done_rounded,
                  alerte: false,
                )
              else
                Carte(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final repas in enAttente)
                        ListTile(
                          leading: const Icon(
                            Icons.schedule_rounded,
                            color: Couleurs.alerte,
                          ),
                          title: Text(repas.nom),
                          trailing: Text(
                            '${_jour(repas.dateHeure)} ${heureCourte(repas.dateHeure)}',
                            style: const TextStyle(color: Couleurs.discret),
                          ),
                        ),
                    ],
                  ),
                ),

              const _Titre('Historique des envois', null),
              if (historique.isEmpty)
                const Bandeau(
                  texte: 'Aucun envoi pour l\'instant.',
                  icone: Icons.history_rounded,
                  alerte: false,
                )
              else
                Carte(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final envoi in historique) _LigneEnvoi(envoi),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _jour(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte, this.nombre);

  final String texte;
  final int? nombre;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
    child: Row(
      children: [
        Text(
          texte,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        if (nombre != null && nombre! > 0) ...[
          const SizedBox(width: 8),
          Pastille('$nombre'),
        ],
      ],
    ),
  );
}

class _LigneEnvoi extends StatelessWidget {
  const _LigneEnvoi(this.envoi);

  final Synchronisation envoi;

  @override
  Widget build(BuildContext context) {
    final date =
        '${envoi.date.day.toString().padLeft(2, '0')}/${envoi.date.month.toString().padLeft(2, '0')} '
        'à ${heureCourte(envoi.date)}';
    final envoyes = nombre(envoi.envoyes, 'repas envoyé', 'repas envoyés');
    final detail = envoi.reussie
        ? (envoi.envoyes > 0
              ? '$envoyes · liste des étudiants à jour'
              : 'Liste des étudiants à jour')
        : 'Échec : ${envoi.message ?? 'problème inconnu'}'
              '${envoi.envoyes > 0 ? ' ($envoyes avant le problème)' : ''}';
    return ListTile(
      leading: Icon(
        envoi.reussie ? Icons.check_circle_rounded : Icons.error_rounded,
        color: envoi.reussie ? Couleurs.vert : Couleurs.danger,
      ),
      title: Text(date),
      subtitle: Text(detail),
    );
  }
}
