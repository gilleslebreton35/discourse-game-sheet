// assets/javascripts/discourse/discourse-route-map.js
//
// Ce fichier DOIT être à la racine de assets/javascripts/discourse/
// et exporter une fonction par défaut.
// Discourse le charge automatiquement pour enregistrer les routes Ember.

export default function () {
  this.route("game-sheet", { path: "/game-sheet" });
}
