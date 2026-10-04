import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../domaine/modeles.dart';
import '../../domaine/texte.dart';
import '../../domaine/verification.dart';
import 'elements.dart';
import 'photo_etudiant.dart';

/// Étape intermédiaire du scan : l'étudiant a droit au repas, l'employé vérifie la photo puis valide.
/// Rien n'est enregistré tant que « Valider le repas » n'est pas touché.
class ConfirmationRepas extends StatelessWidget {
  const ConfirmationRepas({
    super.key,
    required this.verdict,
    required this.surValidation,
    required this.surAnnulation,
    required this.enCours,
  });

  final Verdict verdict;
  final VoidCallback surValidation;
  final VoidCallback surAnnulation;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    final etudiant = verdict.etudiant!;
    final externe = etudiant.statut == Statut.externe;
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Couleurs.carte,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhotoEtudiant(etudiant: etudiant, taille: 150),
                const SizedBox(height: 16),
                Text(
                  etudiant.nomComplet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Pastille(externe ? 'Externe' : 'Interne'),
                const SizedBox(height: 14),
                Text(
                  externe
                      ? 'Il lui reste ${nombre(etudiant.soldePlats, 'plat')} · ${etudiant.soldePlats - 1} après ce repas'
                      : verdict.detail ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Couleurs.discret, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vérifiez que la photo correspond à la personne.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Couleurs.discret, fontSize: 13),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                  onPressed: enCours ? null : surValidation,
                  icon: const Icon(Icons.check_rounded, size: 28),
                  label: const Text(
                    'Valider le repas',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: enCours ? null : surAnnulation,
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Couleurs.discret, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
