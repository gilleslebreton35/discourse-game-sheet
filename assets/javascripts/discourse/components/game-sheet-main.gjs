import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import popupAjaxError from "discourse/lib/popup-ajax-error";
import { fn } from "@ember/helper"; // Obligatoire en mode strict pour utiliser (fn ...)

export default class GameSheetMain extends Component {
  @service siteSettings;
  @service router;

  @tracked query = "";
  @tracked results = [];
  @tracked loading = false;
  @tracked selectedGame = null;
  @tracked loadingDetails = false;
  @tracked destinationCategory = "";
  @tracked includeImage = true;
  @tracked selectedVideos = [];
  @tracked creating = false;

  get availableCategories() {
    return this.siteSettings.categories || [];
  }

  // Fonctions de mise à jour explicites (remplacent le "mutex" qui faisait planter le compilateur)
  @action
  updateQuery(event) {
    this.query = event.target.value;
  }

  @action
  updateIncludeImage(event) {
    this.includeImage = event.target.checked;
  }

  @action
  updateCategory(event) {
    this.destinationCategory = event.target.value;
  }

  @action
  async searchGames() {
    if (!this.query) return;
    this.loading = true;
    this.selectedGame = null;

    try {
      const response = await ajax(`/game-sheet-api/search?q=${encodeURIComponent(this.query)}`);
      this.results = response.results || [];
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  async selectGame(gameId) {
    this.loadingDetails = true;
    this.selectedVideos = [];
    try {
      this.selectedGame = await ajax(`/game-sheet-api/details?id=${gameId}`);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingDetails = false;
    }
  }

  @action
  toggleVideo(url) {
    if (this.selectedVideos.includes(url)) {
      this.selectedVideos = this.selectedVideos.filter(v => v !== url);
    } else {
      this.selectedVideos = [...this.selectedVideos, url];
    }
  }

  @action
  async submitTopic() {
    if (!this.destinationCategory) {
      alert("Veuillez sélectionner une catégorie de destination.");
      return;
    }

    this.creating = true;
    try {
      const res = await ajax("/game-sheet-api/create-topic", {
        type: "POST",
        data: {
          game_id: this.selectedGame.id,
          category_id: this.destinationCategory,
          include_image: this.includeImage,
          selected_videos: this.selectedVideos
        }
      });
      window.location.href = res.topic_url;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.creating = false;
    }
  }

  <template>
    <div class="wrap game-sheet-container" style="padding: 20px;">
      <h1>Créateur de Fiches de Jeu</h1>
      
      <div class="search-form" style="display: flex; gap: 10px; margin-bottom: 20px;">
        <input 
          type="text" 
          placeholder="Rechercher un jeu sur BoardGameGeek..." 
          value={{this.query}}
          {{on "input" this.updateQuery}}
          style="flex: 1;"
        />
        <button type="button" class="btn btn-primary" {{on "click" this.searchGames}}>
          {{if this.loading "Recherche..." "Rechercher"}}
        </button>
      </div>

      {{#if this.results.length}}
        <div class="results-list" style="margin-bottom: 30px;">
          <h3>Résultats de recherche</h3>
          <table class="table">
            <thead>
              <tr>
                <th>Image</th>
                <th>Titre</th>
                <th>Année</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.results as |game|}}
                <tr>
                  <td><img src={{game.thumbnail}} style="width: 50px; height: 50px; object-fit: cover;" alt="" /></td>
                  <td><strong>{{{game.name}}}</strong></td>
                  <td>{{game.yearpublished}}</td>
                  <td>
                    <button type="button" class="btn" {{on "click" (fn this.selectGame game.id)}}>Choisir</button>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </div>
      {{/if}}

      {{#if this.loadingDetails}}
        <p>Traduction et chargement des détails du jeu en cours...</p>
      {{/if}}

      {{#if this.selectedGame}}
        <hr />
        <div class="game-configuration" style="display: flex; gap: 20px;">
          
          <div style="flex: 1;">
            <h2>{{{this.selectedGame.name}}} ({{this.selectedGame.yearpublished}})</h2>
            <p>{{{this.selectedGame.description_fr}}}</p>
          </div>

          <div style="flex: 1; background: var(--blend-light); padding: 20px; border-radius: 8px;">
            <h3>Options de la fiche</h3>
            
            <label style="display: block; margin-bottom: 15px;">
              <input type="checkbox" checked={{this.includeImage}} {{on "change" this.updateIncludeImage}} />
              Inclure l'image principale du jeu dans le sujet
            </label>

            {{#if this.selectedGame.videos.length}}
              <h4>Sélectionner les vidéos à inclure :</h4>
              {{#each this.selectedGame.videos as |video|}}
                <label style="display: block; margin-bottom: 8px;">
                  <input type="checkbox" {{on "change" (fn this.toggleVideo video.link)}} />
                  {{video.title}}
                </label>
              {{/each}}
            {{/if}}

            <div style="margin-top: 20px;">
              <h4>Catégorie de destination :</h4>
              <select {{on "change" this.updateCategory}}>
                <option value="">-- Choisir une catégorie --</option>
                {{#each this.availableCategories as |cat|}}
                  <option value={{cat.id}}>{{cat.name}}</option>
                {{/each}}
              </select>
            </div>

            <button 
              type="button" 
              class="btn btn-danger" 
              style="margin-top: 30px; width: 100%; font-size: 1.2em;" 
              {{on "click" this.submitTopic}}
              disabled={{this.creating}}
            >
              {{if this.creating "Création du sujet en cours..." "🚀 Générer et Créer le Sujet"}}
            </button>
          </div>

        </div>
      {{/if}}
    </div>
  </template>
}
