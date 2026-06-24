import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import { Input } from "@ember/component";

export default class AdminGameSheet extends Component {
  @service siteSettings;

  @tracked query = "";
  @tracked results = [];
  @tracked loading = false;
  @tracked error = null;
  @tracked createdTopicUrl = null;
  @tracked creatingId = null;

  @action
  async searchGames() {
    if (!this.query || this.query.trim() === "") return;

    this.loading = true;
    this.error = null;
    this.results = [];
    this.createdTopicUrl = null;

    try {
      const response = await ajax(`/game-sheet/search?q=${encodeURIComponent(this.query)}`);
      
      // CORRECTION 1 : On cible bien la propriété .results du JSON
      this.results = response.results || [];
      
      if (this.results.length === 0) {
        this.error = i18n("game_sheet.no_results") || "Aucun jeu trouvé.";
      }
    } catch (e) {
      const errorMessage = e.jqXHR?.responseJSON?.errors?.[0] || "Erreur de connexion avec le serveur.";
      this.error = errorMessage;
    } finally {
      this.loading = false;
    }
  }

  @action
  async createTopic(gameId) {
    this.creatingId = gameId;
    this.error = null;
    this.createdTopicUrl = null;

    try {
      const response = await ajax("/game-sheet/create-topic", {
        type: "POST",
        data: { 
          game_id: gameId,
          category_id: this.siteSettings.game_sheet_allowed_category_id 
        },
      });

      if (response && response.topic_url) {
        this.createdTopicUrl = response.topic_url;
      }
    } catch (e) {
      const errorMessage = e.jqXHR?.responseJSON?.errors?.[0] || "Erreur lors de la création du sujet.";
      this.error = errorMessage;
    } finally {
      this.creatingId = null;
    }
  }

  <template>
    <div class="game-sheet-admin-container">
    </div>
    <div class="admin-container">
      <h1>{{i18n "game_sheet.title"}}</h1>

      <div style="margin: 1em 0;">
        <label>{{i18n "game_sheet.search_label"}}</label>
        <div style="display:flex; gap: 0.5em; margin-top: 0.5em;">
          <Input
            @type="text"
            @value={{this.query}}
            placeholder={{i18n "game_sheet.search_placeholder"}}
          />
          <DButton
            @label="game_sheet.search_button"
            @action={{this.searchGames}}
            @disabled={{this.loading}}
            class="btn-primary"
          />
        </div>
      </div>

      {{#if this.error}}
        <div class="alert alert-error" style="margin-bottom: 1em;">
          {{this.error}}
        </div>
      {{/if}}

      {{#if this.createdTopicUrl}}
        <div class="alert alert-success" style="margin-bottom: 1em;">
          {{i18n "game_sheet.success"}}
          <a href={{this.createdTopicUrl}} target="_blank" rel="noopener noreferrer">
            {{i18n "game_sheet.open_topic"}}
          </a>
        </div>
      {{/if}}

      {{#if this.results.length}}
        <table class="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Nom</th>
              <th>Année</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each this.results as |game|}}
              <tr>
                <td>{{game.id}}</td>
                <td>{{game.name.normalized}}</td>
                <td>{{game.yearpublished.normalized}}</td>
                <td>
                  <DButton
                    @label="game_sheet.create_topic"
                    @action={{fn this.createTopic game.id}}
                    @disabled={{this.creatingId}}
                    class="btn-primary"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else if this.loading}}
        <p>Chargement...</p>
      {{/if}}
    </div>
  </template>
}
