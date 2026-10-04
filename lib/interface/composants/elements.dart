/// Petits éléments visuels partagés par les écrans.
library;

import 'package:flutter/material.dart';

import '../../config/theme.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, this.taille = 44, this.avecNom = true});

  final double taille;
  final bool avecNom;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: taille,
          height: taille,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Couleurs.vert, width: 3),
          ),
          child: Center(
            child: Container(
              width: taille * .42,
              height: taille * .42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Couleurs.vert, width: 2.5),
              ),
            ),
          ),
        ),
        if (avecNom) ...[
          const SizedBox(width: 10),
          const Text(
            'Resto Connect',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// Carte blanche arrondie, comme sur le front Gérant.
class Carte extends StatelessWidget {
  const Carte({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  // Une vraie surface Material : les effets au toucher des éléments posés dessus restent visibles.
  @override
  Widget build(BuildContext context) => Material(
    color: Couleurs.carte,
    borderRadius: BorderRadius.circular(22),
    child: Padding(padding: padding, child: child),
  );
}

/// Bandeau d'information ou d'alerte.
class Bandeau extends StatelessWidget {
  const Bandeau({
    super.key,
    required this.texte,
    this.icone = Icons.info_outline_rounded,
    this.alerte = true,
  });

  final String texte;
  final IconData icone;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final couleur = alerte ? Couleurs.alerte : Couleurs.vert;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alerte ? Couleurs.alertePale : Couleurs.vertPale,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icone, color: couleur),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texte, style: TextStyle(color: couleur, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Petite étiquette arrondie (type contrôlé, créneau…).
class Pastille extends StatelessWidget {
  const Pastille(this.texte, {super.key, this.sombre = false});

  final String texte;
  final bool sombre;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: sombre ? Colors.white.withValues(alpha: .16) : Couleurs.vertPale,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      texte,
      style: TextStyle(
        color: sombre ? Colors.white : Couleurs.vertFonce,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );
}

void afficherMessage(BuildContext context, String? message) {
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String heureCourte(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
