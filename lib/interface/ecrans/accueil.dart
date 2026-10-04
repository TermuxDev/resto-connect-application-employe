import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../domaine/modeles.dart';
import '../../etat/etat_terminal.dart';
import '../composants/elements.dart';
import 'aide.dart';
import 'envois.dart';

/// Menu principal : état du terminal, service en cours, envois et mises à jour.
class EcranAccueil extends StatelessWidget {
  const EcranAccueil({super.key, required this.etat});

  final EtatTerminal etat;

  Future<void> _rechercher(BuildContext context) async {
    final message = await etat.rechercherMisesAJour();
    if (context.mounted) afficherMessage(context, message);
  }

  Future<void> _deconnecter(BuildContext context) async {
    final message = await etat.deconnecter();
    if (context.mounted) afficherMessage(context, message);
  }

  Future<void> _terminer(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer le service ?'),
        content: Text(
          '${etat.servisDuService} repas servis. Ils seront envoyés au serveur '
          'dès que la connexion le permet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (confirme != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = await etat.terminerService();
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _ouvrirEnvois(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => EcranEnvois(etat: etat)));

  @override
  Widget build(BuildContext context) {
    final terminal = etat.terminal;
    final synchro = etat.derniereSynchro;
    final service = etat.service;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: Couleurs.vert,
          onRefresh: () => _rechercher(context),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Logo(),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Aide',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EcranAide(version: etat.version),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Envois',
                    onPressed: () => _ouvrirEnvois(context),
                    icon: Badge(
                      isLabelVisible: etat.enAttente > 0,
                      label: Text('${etat.enAttente}'),
                      child: const Icon(Icons.cloud_upload_outlined),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Déconnexion',
                    onPressed: etat.occupe ? null : () => _deconnecter(context),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Carte principale : le service en cours, ou le terminal prêt à démarrer.
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: Couleurs.degrade,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      terminal?.nom ?? 'Terminal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (service != null)
                      Pastille(
                        service.creneau == Creneau.libre
                            ? 'Service en cours depuis ${heureCourte(service.ouverture.toLocal())}'
                            : 'Service du ${service.creneau.libelle} en cours',
                        sombre: true,
                      )
                    else if (terminal != null)
                      Pastille(
                        'Contrôle les ${terminal.typeVerifie.pluriel}',
                        sombre: true,
                      ),
                    const SizedBox(height: 22),
                    Text(
                      service != null
                          ? '${etat.servisDuService}'
                          : '${etat.etudiantsCharges}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    Text(
                      service != null
                          ? 'repas servis pendant ce service'
                          : 'étudiants chargés sur ce téléphone',
                      style: const TextStyle(color: Couleurs.vertClair),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Indicateur(
                        valeur: '${etat.enAttente}',
                        libelle: 'repas en attente d\'envoi',
                        alerte: etat.enAttente > 0,
                        surAppui: () => _ouvrirEnvois(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _Indicateur(
                        valeur: synchro == null ? '—' : heureCourte(synchro),
                        libelle: synchro == null
                            ? 'pas encore mis à jour'
                            : 'dernière mise à jour',
                        surAppui: () => _ouvrirEnvois(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (etat.horsLigne) ...[
                const Bandeau(
                  texte:
                      'Pas de connexion au serveur. Vous pouvez quand même servir : les repas seront envoyés plus tard.',
                  icone: Icons.cloud_off_rounded,
                ),
                const SizedBox(height: 14),
              ],
              if (etat.horlogeDereglee) ...[
                Bandeau(
                  texte:
                      'L\'heure du téléphone n\'est pas bonne (${etat.ecartHorloge!.inMinutes.abs()} min d\'écart). '
                      'Réglez la date et l\'heure en « automatique » dans les paramètres du téléphone.',
                  icone: Icons.schedule_rounded,
                ),
                const SizedBox(height: 14),
              ],
              if (!etat.pret) ...[
                const Bandeau(
                  texte:
                      'La liste des étudiants n\'est pas encore chargée. Touchez « Rechercher les mises à jour ».',
                  icone: Icons.download_rounded,
                ),
                const SizedBox(height: 14),
              ],

              const SizedBox(height: 10),
              if (service != null) ...[
                FilledButton.icon(
                  onPressed: etat.reprendreService,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Reprendre le scan'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Couleurs.danger,
                    side: const BorderSide(color: Couleurs.danger),
                  ),
                  onPressed: etat.occupe ? null : () => _terminer(context),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Terminer le service'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: etat.pret && !etat.occupe
                      ? etat.demarrerService
                      : null,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Démarrer le service'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: etat.occupe ? null : () => _rechercher(context),
                icon: etat.occupe
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  etat.occupe ? 'Mise à jour…' : 'Rechercher les mises à jour',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Version ${etat.version}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Couleurs.discret, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicateur extends StatelessWidget {
  const _Indicateur({
    required this.valeur,
    required this.libelle,
    required this.surAppui,
    this.alerte = false,
  });

  final String valeur;
  final String libelle;
  final VoidCallback surAppui;
  final bool alerte;

  @override
  Widget build(BuildContext context) => Material(
    color: Couleurs.carte,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: surAppui,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valeur,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: alerte ? Couleurs.alerte : Couleurs.texte,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              libelle,
              style: const TextStyle(color: Couleurs.discret, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
