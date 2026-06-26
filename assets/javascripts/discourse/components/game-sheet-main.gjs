import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { fn } from "@ember/helper";

export default class GameSheetMain extends Component {
  @service site; // Utilisation du service site natif

  @tracked query = "";
  @tracked results = [];
  @tracked loading = false;
  @tracked selectedGame = null;
  @tracked loadingDetails = false;
  @tracked destinationCategory = "";
  @tracked creating = false;

  // On récupère les catégories via le service 'site' de Discourse
  get availableCategories() {
    return this.site.categories || [];
  }

  @action updateQuery(event) { this.query = event.target.value; }
  @action updateCategory(event) { this.destinationCategory = event.target.value; }

  @action
  async searchGames() {
    if (!this.query) return;
    this.loading = true;
    try {
      const response = await ajax(`/game-sheet-api/search?q=${encodeURIComponent(this.query)}`);
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
          category_id: this.destinationCategory
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
        <input type="text" placeholder="Rechercher..." value={{this.query}} {{on "input" this.updateQuery}} />
        <button type="button" class="btn btn-primary" {{on "click" this.searchGames}}>
          {{if this.loading "..." "Rechercher"}}
        </button>
      </div>

      {{#if this.results.length}}
        <ul style="list-style: none; padding: 0;">
          {{#each this.results as |game|}}
            <li style="display: flex; align-items: center; gap: 15px; margin-bottom: 10px; border-bottom: 1px solid #444; padding: 5px;">
              {{#if game.image}}<img src={{game.image}} width="50" alt="" />{{/if}}
              <div style="flex-grow: 1;">
                <strong>{{game.name}}</strong> ({{game.yearpublished}})
              </div>
              <button type="button" class="btn" {{on "click" (fn this.selectGame game.id)}}>Choisir</button>
            </li>
          {{/each}}
        </ul>
      {{/if}}
      
      {{#if this.selectedGame}}
        <div style="margin-top: 30px; border: 1px solid #ddd; padding: 20px;">
          <h2>{{this.selectedGame.name}}</h2>
          <img src={{this.selectedGame.image}} width="200" alt="box" />
          
          <div style="margin: 15px 0;">
            <label>Choisir la catégorie :</label>
            <select {{on "change" this.updateCategory}}>
              <option value="">-- Sélectionner --</option>
              {{#each this.availableCategories as |cat|}}
                <option value={{cat.id}}>{{cat.name}}</option>
              {{/each}}
            </select>
          </div>

          <button type="button" class="btn btn-danger" {{on "click" this.submitTopic}} disabled={{this.creating}}>
            {{if this.creating "Création..." "Créer le sujet"}}
          </button>
        </div>
      {{/if}}
    </div>
  </template>
}
