# LeLion multi : Plan de la phase 7 (Teinte de la crinière)

Date : 2026-09-25 · Phase : 7 / **Teinte de la crinière** · Statut : planification

## Objectif

Implémenter la teinte du lion (seule la crinière) à partir du masque déduit pixel par pixel par le
shader, sans masques générés. Un lion sans couleur (solo) n'a aucun matériau. Ajouter le pseudo
au-dessus du lion. Préparer les uniformes de barbouillage pour les phases suivantes.

## Décisions de phase

- Le shader `Lion.gdshader` déduit le masque du sprite lui-même : la crinière est dans les teintes
  du violet au rouge, le visage dans l'orange et le jaune (exclu par sa teinte), la langue et les
  reflets sont trop clairs, le contour trop sombre.
- Un seul shader vaut pour les deux sprites (repos et vomi), sans masque généré.
- Un joueur sans couleur (alpha 0, le solo) laisse le sprite sans matériau.
- **Repli** si le masque est laid : rotation de teinte de toute la tête.

## Fichiers à modifier

| Fichier | Action | Notes |
|---------|--------|-------|
| `Shaders/Lion.gdshader` | Créer | Shader déduisant le masque du sprite |
| `Scripts/Joueur.gd` | Modifier | Support de couleur transparente (solo) |
| `Scripts/Lion.gd` | Modifier | Application de la teinte et du barbouillage |
| `Scenes/Lion.tscn` | Modifier | Configuration du matériau et du pseudo |
| `tests/smoke_test.gd` | Modifier | Vérification du rendu (adapté à la nouvelle structure) |

## Vérification

```sh
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-multi
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
godot --headless --script tests/smoke_test.gd
```

Smoke test doit finir sur `== 0 échec(s) ==` et code de sortie 0.
Sortie ne doit contenir ni `SCRIPT ERROR` ni `SHADER ERROR`.

Après création du shader : lancer `godot --headless --import .` (génère le `.uid`, met à jour le cache d'import).

Toute modification du smoke test doit être validée sur **5 passages consécutifs verts**.

## Sortie visuelle (◉ contrôle en fin de phase)

6 lions teintés dans le salon (couleurs : rouge, bleu, jaune, vert, magenta, cyan).
- Solo (7e lion) : rendu identique à avant, sans teinte.
- Pseudo affiché au-dessus du lion en bataille seulement, dans la couleur du joueur.

## Notes

- La planche de contrôle (`rendu_lions.gd`, `planche_lions.py`) vit dans le scratchpad et **n'est pas commitée**.
- `Shaders/Lion.gdshader.uid` est commité avec le shader, hors plafond de 5 fichiers.
- Le barbouillage utilise les uniformes `barbouillage_couleur` et `barbouillage_force` du matériau, prêts à 0.
- Phase obligatoire avant bataille : `Lion.gd` nomme `GameState` et `Audio`, donc les tests `--script` (compilés avant les autoloads) typent les lions en `Node` / `CharacterBody2D`, jamais `Lion`.
