import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { fn } from "@ember/helper";

export default class GameSheetMain extends Component {
  @service siteSettings;

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

  @action updateQuery(event) { this.query = event.target.value; }
  @action updateIncludeImage(event) { this.includeImage = event.target.checked; }
  @action updateCategory(event) { this.destinationCategory = event.target.value; }

  @action
  async searchGames() {
    if (!this.query) return;
    this.loading = true;
    this.results = [];
    try {
      const response = await ajax(`/game-sheet-api/search?q=${encodeURIComponent(this.query)}`);
      // Correction ici : Utilisation de response.bgg
      this.results = response.bgg || [];
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  async selectGame(gameId) {
    this.loadingDetails = true;
    try {
      this.selectedGame = await ajax(`/game-sheet-api/details/${gameId}`);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingDetails = false;
    }
  }

  @action
  async submitTopic() {
    if (!this.destinationCategory) {
      alert("Veuillez sélectionner une catégorie.");
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
    <div class="wrap" style="padding: 20px;">
      <h1>Créateur de Fiches</h1>
      <div style="display: flex; gap: 10px; margin-bottom: 20px;">
        <input type="text" placeholder="Rechercher un jeu..." value={{this.query}} {{on "input" this.updateQuery}} />
        <button type="button" class="btn btn-primary" {{on "click" this.searchGames}}>
          {{if this.loading "..." "Rechercher"}}
        </button>
      </div>

      {{#if this.results.length}}
        <ul>
          {{#each this.results as |game|}}
            <li>{{game.name}} <button type="button" {{on "click" (fn this.selectGame game.id)}}>Choisir</button></li>
          {{/each}}
        </ul>
      {{/if}}
      
      {{#if this.selectedGame}}
        <h2>{{this.selectedGame.name}}</h2>
        <button type="button" class="btn btn-danger" {{on "click" this.submitTopic}}>Créer le sujet</button>
      {{/if}}
    </div>
  </template>
}
