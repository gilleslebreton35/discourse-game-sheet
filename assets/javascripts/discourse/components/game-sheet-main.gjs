{{! assets/javascripts/discourse/components/game-sheet-main.gjs }}

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class GameSheetMain extends Component {
  @service siteSettings;
  @service router;
  @service site;          // ← donne accès à this.site.categories

  @tracked query          = "";
  @tracked results        = [];
  @tracked loading        = false;
  @tracked selectedGame   = null;
  @tracked loadingDetails = false;
  @tracked destinationCategory = "";
  @tracked includeImage   = true;
  @tracked selectedVideos = [];
  @tracked creating       = false;
  @tracked createdUrl     = null;

  // ── Catégories disponibles ────────────────────────────────────────────────
  // this.site.categories contient toutes les catégories visibles par l'utilisateur.
  // On peut filtrer via un réglage de site si besoin.
  get availableCategories() {
    return this.site.categories ?? [];
  }

  // ── Handlers formulaire ───────────────────────────────────────────────────
  @action updateQuery(e)        { this.query            = e.target.value; }
  @action updateIncludeImage(e) { this.includeImage     = e.target.checked; }
  @action updateCategory(e)     { this.destinationCategory = e.target.value; }

  // ── Recherche ─────────────────────────────────────────────────────────────
  @action
  async searchGames() {
    if (!this.query.trim()) return;
    this.loading = true;
    this.selectedGame = null;
    this.results = [];

    try {
      const response = await ajax(
        `/game-sheet-api/search?q=${encodeURIComponent(this.query)}`
      );
      this.results = response.results ?? [];
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  // Permet de lancer la recherche avec la touche Entrée
  @action
  onKeydown(e) {
    if (e.key === "Enter") this.searchGames();
  }

  // ── Sélection d'un jeu ────────────────────────────────────────────────────
  @action
  async selectGame(gameId) {
    this.loadingDetails = true;
    this.selectedGame   = null;
    this.selectedVideos = [];

    try {
      const data = await ajax(`/game-sheet-api/details?id=${gameId}`);
      this.selectedGame = data;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingDetails = false;
    }
  }

  // ── Vidéos ────────────────────────────────────────────────────────────────
  @action
  toggleVideo(url) {
    if (this.selectedVideos.includes(url)) {
      this.selectedVideos = this.selectedVideos.filter((v) => v !== url);
    } else {
      this.selectedVideos = [...this.selectedVideos, url];
    }
  }

  isVideoSelected(url) {
    return this.selectedVideos.includes(url);
  }

  // ── Création du sujet ─────────────────────────────────────────────────────
  @action
  async submitTopic() {
    if (!this.destinationCategory) {
      alert("Veuillez sélectionner une catégorie de destination.");
      return;
    }

    this.creating    = true;
    this.createdUrl  = null;

    try {
      const res = await ajax("/game-sheet-api/create-topic", {
        type: "POST",
        data: {
          game_id:         this.selectedGame.id,
          category_id:     this.destinationCategory,
          include_image:   this.includeImage,
          selected_videos: this.selectedVideos,
        },
      });
      this.createdUrl = res.topic_url;
      window.location.href = res.topic_url;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.creating = false;
    }
  }

  // ── Template ──────────────────────────────────────────────────────────────
  <template>
    <div class="wrap game-sheet-container">
      <h1>🎲 Créateur de Fiches de Jeu</h1>

      {{! ── Barre de recherche ── }}
      <div class="game-sheet-search-bar">
        <input
          type="text"
          class="game-sheet-input"
          placeholder="Rechercher un jeu sur BoardGameGeek..."
          value={{this.query}}
          {{on "input"   this.updateQuery}}
          {{on "keydown" this.onKeydown}}
        />
        <button
          type="button"
          class="btn btn-primary"
          disabled={{this.loading}}
          {{on "click" this.searchGames}}
        >
          {{if this.loading "Recherche en cours…" "Rechercher"}}
        </button>
      </div>

      {{! ── Résultats de recherche ── }}
      {{#if this.results.length}}
        <div class="game-sheet-results">
          <h3>Résultats</h3>
          <table class="table">
            <thead>
              <tr>
                <th>Image</th><th>Titre</th><th>Année</th><th></th>
              </tr>
            </thead>
            <tbody>
              {{#each this.results as |game|}}
                <tr>
                  <td>
                    {{#if game.thumbnail}}
                      {{! Double accolades uniquement — jamais triple dans .gjs }}
                      <img
                        src={{game.thumbnail}}
                        class="game-sheet-thumb"
                        alt=""
                      />
                    {{/if}}
                  </td>
                  <td><strong>{{game.name}}</strong></td>
                  <td>{{game.yearpublished}}</td>
                  <td>
                    <button
                      type="button"
                      class="btn btn-small"
                      {{on "click" (fn this.selectGame game.id)}}
                    >
                      Choisir
                    </button>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </div>
      {{/if}}

      {{! ── Chargement des détails ── }}
      {{#if this.loadingDetails}}
        <div class="game-sheet-loading">
          <p>⏳ Traduction et chargement des détails du jeu…</p>
        </div>
      {{/if}}

      {{! ── Détails + options ── }}
      {{#if this.selectedGame}}
        <hr />
        <div class="game-sheet-details">

          {{! Colonne gauche : aperçu }}
          <div class="game-sheet-preview">
            {{#if this.selectedGame.image}}
              <img
                src={{this.selectedGame.image}}
                class="game-sheet-cover"
                alt={{this.selectedGame.name}}
              />
            {{/if}}
            <h2>{{this.selectedGame.name}}
              {{#if this.selectedGame.yearpublished}}
                <span class="game-sheet-year">({{this.selectedGame.yearpublished}})</span>
              {{/if}}
            </h2>
            {{! Pas de triple accolades : utiliser un <p> avec du HTML échappé est plus sûr }}
            <p class="game-sheet-description">{{this.selectedGame.description_fr}}</p>
          </div>

          {{! Colonne droite : options }}
          <div class="game-sheet-options">
            <h3>Options de la fiche</h3>

            <label class="game-sheet-checkbox-label">
              <input
                type="checkbox"
                checked={{this.includeImage}}
                {{on "change" this.updateIncludeImage}}
              />
              Inclure l'image principale dans le sujet
            </label>

            {{#if this.selectedGame.videos.length}}
              <div class="game-sheet-videos">
                <h4>Vidéos à inclure :</h4>
                {{#each this.selectedGame.videos as |video|}}
                  <label class="game-sheet-checkbox-label">
                    <input
                      type="checkbox"
                      {{on "change" (fn this.toggleVideo video.link)}}
                    />
                    {{video.title}}
                  </label>
                {{/each}}
              </div>
            {{/if}}

            <div class="game-sheet-category">
              <h4>Catégorie de destination :</h4>
              <select class="game-sheet-select" {{on "change" this.updateCategory}}>
                <option value="">-- Choisir une catégorie --</option>
                {{#each this.availableCategories as |cat|}}
                  <option value={{cat.id}}>{{cat.name}}</option>
                {{/each}}
              </select>
            </div>

            <button
              type="button"
              class="btn btn-primary game-sheet-submit"
              disabled={{this.creating}}
              {{on "click" this.submitTopic}}
            >
              {{if this.creating "Création en cours…" "🚀 Générer et créer le sujet"}}
            </button>
          </div>

        </div>
      {{/if}}
    </div>
  </template>
}
