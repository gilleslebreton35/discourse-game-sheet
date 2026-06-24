import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import { Input } from "@ember/component";

// Fonctionnalités utilitaires pures (Évite l'usage de helpers globaux obsolètes)
const isSelected = (selectedGame, currentId) => selectedGame?.id === currentId;
const isImageChecked = (list, url) => list && list.includes(url);
const computeThumbnailStyle = (list, url) => {
  const checked = list && list.includes(url);
  return `width: 76px; height: 76px; object-fit: cover; border-radius: 6px; cursor: pointer; transition: all 0.2s ease; border: 3px solid ${checked ? "var(--tertiary)" : "var(--primary-low)"}; opacity: ${checked ? "1" : "0.7"};`;
};

export default class AdminGameSheet extends Component {
  @service siteSettings;

  // États de la recherche globale
  @tracked query = "";
  @tracked results = [];
  @tracked loading = false;
  @tracked error = null;
  @tracked createdTopicUrl = null;
  
  // États d'isolation du panneau de détails (Étape 2)
  @tracked selectedGame = null;
  @tracked loadingDetails = false;
  @tracked selectedImages = [];
  @tracked creatingTopic = false;

  @action
  async searchGames() {
    if (!this.query || !this.query.trim()) return;

    this.loading = true;
    this.error = null;
    this.results = [];
    this.createdTopicUrl = null;
    this.selectedGame = null; 

    try {
      const response = await ajax(`/game-sheet/search?q=${encodeURIComponent(this.query)}`);
      this.results = response.results || [];
      
      if (this.results.length === 0) {
        this.error = i18n("game_sheet.no_results") || "Aucun jeu trouvé.";
      }
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.errors?.[0] || "Erreur lors de la communication avec le serveur backend.";
    } finally {
      this.loading = false;
    }
  }

  @action
  async loadGameDetails(gameId) {
    this.loadingDetails = true;
    this.error = null;
    this.selectedGame = null;
    this.selectedImages = []; 

    try {
      const response = await ajax(`/game-sheet/details?id=${gameId}`);
      this.selectedGame = response;
      
      // Expérience Utilisateur : Pré-sélectionner automatiquement la couverture par défaut
      if (this.selectedGame?.images?.length > 0) {
        this.selectedImages = [this.selectedGame.images[0]];
      }
    } catch (e) {
      this.error = "Erreur critique : Impossible de récupérer la fiche technique BGG de ce jeu.";
    } finally {
      this.loadingDetails = false;
    }
  }

  @action
  toggleImageSelection(imageUrl) {
    if (this.selectedImages.includes(imageUrl)) {
      this.selectedImages = this.selectedImages.filter(img => img !== imageUrl);
    } else {
      this.selectedImages = [...this.selectedImages, imageUrl];
    }
  }

  @action
  async executeTopicCreation() {
    if (!this.selectedGame) return;

    this.creatingTopic = true;
    this.error = null;
    this.createdTopicUrl = null;

    const payload = {
      game_id: this.selectedGame.id,
      category_id: this.siteSettings.game_sheet_allowed_category_id || 1,
      selected_images: this.selectedImages
    };

    try {
      const response = await ajax("/game-sheet/create-topic", {
        type: "POST",
        data: payload
      });

      if (response?.topic_url) {
        this.createdTopicUrl = response.topic_url;
        document.querySelector(".game-sheet-admin-viewport")?.scrollIntoView({ behavior: "smooth" });
      }
    } catch (e) {
      this.error = e.jqXHR?.responseJSON?.errors?.[0] || "Erreur critique lors de la sérialisation du sujet.";
    } finally {
      this.creatingTopic = false;
    }
  }

  <template>
    <div class="game-sheet-admin-viewport admin-container">
      <h1>{{i18n "game_sheet.title"}}</h1>

      <div class="game-sheet-search-block">
        <label for="bgg-search-input">{{i18n "game_sheet.search_label"}}</label>
        <div class="game-sheet-input-group">
          <Input
            @type="text"
            @value={{this.query}}
            id="bgg-search-input"
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
        <div class="alert alert-error animate-fade-in">
          {{this.error}}
        </div>
      {{/if}}

      {{#if this.createdTopicUrl}}
        <div class="alert alert-success animate-fade-in">
          {{i18n "game_sheet.success"}}
          <a href={{this.createdTopicUrl}} target="_blank" rel="noopener noreferrer">
            {{i18n "game_sheet.open_topic"}}
          </a>
        </div>
      {{/if}}

      <div class="game-sheet-workspace">
        
        {{#if this.results.length}}
          <div class="game-sheet-results-pane">
            <table class="table game-sheet-data-table">
              <thead>
                <tr>
                  <th>Nom du Jeu</th>
                  <th>Année</th>
                  <th class="actions-col"></th>
                </tr>
              </thead>
              <tbody>
                {{#each this.results as |game|}}
                  <tr class={{if (isSelected this.selectedGame game.id) "is-active-row"}}>
                    <td class="game-title-cell">{{game.name.normalized}}</td>
                    <td><span class="date-badge">{{game.yearpublished.normalized}}</span></td>
                    <td class="actions-col">
                      <DButton
                        @icon="eye"
                        @label="game_sheet.view_details"
                        @action={{fn this.loadGameDetails game.id}}
                        class="btn-default btn-small"
                      />
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </div>
        {{else if this.loading}}
          <div class="game-sheet-loading-state">
            <div class="spinner"></div>
            <p>Interrogation de BoardGameGeek en cours...</p>
          </div>
        {{/if}}

        {{#if this.selectedGame}}
          <div class="game-sheet-details-pane">
            <h2>{{this.selectedGame.name}}</h2>
            
            <div class="game-sheet-metadata-strip">
              <span class="meta-item"><i class="fa fa-star"></i> <strong>{{this.selectedGame.rating}}</strong> / 10</span>
              <span class="meta-item"><i class="fa fa-users"></i> <strong>{{this.selectedGame.min_players}} - {{this.selectedGame.max_players}}</strong> joueurs</span>
              <span class="meta-item"><i class="fa fa-clock"></i> <strong>{{this.selectedGame.playing_time}}</strong> min</span>
            </div>

            <div class="game-sheet-description-box">
              {{{this.selectedGame.description}}}
            </div>

            <div class="game-sheet-gallery-section">
              <h3>Sélection des visuels à inclure</h3>
              {{#if this.selectedGame.images.length}}
                <div class="game-sheet-grid-gallery">
                  {{#each this.selectedGame.images as |imgUrl|}}
                    <label class="game-sheet-gallery-item">
                      <img src={{imgUrl}} alt="BGG Resource" style={{computeThumbnailStyle this.selectedImages imgUrl}} />
                      <input 
                        type="checkbox" 
                        class="game-sheet-hidden-checkbox"
                        checked={{isImageChecked this.selectedImages imgUrl}}
                        {{on "change" (fn this.toggleImageSelection imgUrl)}} 
                      />
                    </label>
                  {{/each}}
                </div>
              {{else}}
                <p class="no-data-msg">Aucun visuel d'illustration trouvé pour ce titre.</p>
              {{/if}}
            </div>

            <DButton
              @icon="plus"
              @label="game_sheet.create_topic_button"
              @action={{this.executeTopicCreation}}
              @disabled={{this.creatingTopic}}
              class="btn-primary game-sheet-submit-btn"
            />
          </div>
        {{else if this.loadingDetails}}
          <div class="game-sheet-details-placeholder-loading">
            <div class="spinner"></div>
            <p>Hydratation de la fiche technique depuis BGG...</p>
          </div>
        {{/if}}

      </div>
    </div>
  </template>
}
