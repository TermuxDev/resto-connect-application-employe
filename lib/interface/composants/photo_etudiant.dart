import 'dart:io';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../domaine/modeles.dart';

/// Photo ronde de l'étudiant ; ses initiales si la photo n'a pas encore été téléchargée.
class PhotoEtudiant extends StatelessWidget {
  const PhotoEtudiant({super.key, required this.etudiant, this.taille = 56});

  final Etudiant etudiant;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final chemin = etudiant.photoChemin;
    final initiales = Center(
      child: Text(
        '${etudiant.prenom.characters.first}${etudiant.nom.characters.first}'
            .toUpperCase(),
        style: TextStyle(
          color: Couleurs.vertFonce,
          fontWeight: FontWeight.w700,
          fontSize: taille * .34,
        ),
      ),
    );
    return Container(
      width: taille,
      height: taille,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Couleurs.vertPale,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: chemin == null
          ? initiales
          : Image.file(
              File(chemin),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initiales,
            ),
    );
  }
}
