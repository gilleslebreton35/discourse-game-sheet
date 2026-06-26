// assets/javascripts/discourse/routes/game-sheet.js
//
// La route Ember pour /game-sheet.
// Elle doit étendre DiscourseRoute (et non Route d'Ember directement)
// pour être reconnue par Discourse.

import DiscourseRoute from "discourse/routes/discourse";

export default class GameSheetRoute extends DiscourseRoute {
  // titleToken est affiché dans l'onglet du navigateur
  titleToken() {
    return "Créateur de fiches de jeu";
  }
}
