import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";

export default class GameSheet extends Component {
  @service siteSettings;

  @tracked query = "";
  @tracked results = [];
  @tracked loading = false;
  @tracked error = null;
  @tracked createdTopicUrl = null;

  @tracked selectedGame = null;
  @tracked loadingDetails = false;
  @tracked selectedImages = [];
  @tracked selectedVideos = [];
  @tracked creatingTopic = false;

  @action
  updateQuery(event) {
    this.query = event.target.value;
  }

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
        this.error = "Aucun jeu trouvé.";
      }
    } catch (e) {
      this.error = "Erreur de connexion.";
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
    this.selectedVideos = [];

    try {
      const response = await ajax(`/game-sheet/game/${gameId}`);
      this.selectedGame = response;

      if (this.selectedGame?.images?.length > 0) {
        this.selectedImages = [this.selectedGame.images[0]];
      }
      if (this.selectedGame?.videos?.length > 0) {
        this.selectedVideos = [this.selectedGame.videos[0].id];
      }
    } catch (e) {
      this.error = "Impossible de récupérer les détails du jeu.";
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
  toggleVideoSelection(videoId) {
    if (this.selectedVideos.includes(videoId)) {
      this.selectedVideos = this.selectedVideos.filter(v => v !== videoId);
    } else {
      this.selectedVideos = [...this.selectedVideos, videoId];
    }
  }

  @action
  isImageSelected(imgUrl) {
    return this.selectedImages.includes(imgUrl);
  }

  @action
  isVideoSelected(videoId) {
    return this.selectedVideos.includes(videoId);
  }

  @action
  async executeTopicCreation() {
    if (!this.selectedGame) return;

    this.creatingTopic = true;
    this.error = null;
    this.createdTopicUrl = null;

    const payload = {
      game_id: this.selectedGame.id,
      category_id: this.siteSettings.game_sheet_allowed_category_id,
      selected_images: this.selectedImages,
      selected_videos: this.selectedVideos
    };

    try {
      const response = await ajax("/game-sheet/create-topic", {
        type: "POST",
        data: payload
      });

      if (response?.topic_url) {
        this.createdTopicUrl = response.topic_url;
      }
    } catch (e) {
      this.error = "Erreur lors de la création du sujet.";
    } finally {
      this.creatingTopic = false;
    }
  }

  <template>
    <div class="container">
      <div class="game-sheet-header" style="text-align: center; margin: 2em 0;">
        <h1>🎲 Créer une fiche de jeu</h1>
        <p style="color: var(--primary-medium);">Recherchez un jeu sur BoardGameGeek et créez une fiche dans votre forum</p>
      </div>

      <div style="max-width: 800px; margin: 0 auto;">
        <div style="background: var(--primary-very-low); padding: 1.5em; border-radius: 8px; margin-bottom: 1.5em;">
          <h3>Rechercher un jeu</h3>
          <div style="display: flex; gap: 0.5em; margin-top: 0.5em;">
            <input
              type="text"
              value={{this.query}}
              {{on "input" this.updateQuery}}
              placeholder="Nom du jeu (ex: Catan, Pandemic...)"
              class="input-xxlarge"
              style="flex: 1;"
            />
            <DButton
              @label="Chercher"
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
            ✅ Fiche créée avec succès !
            <a href={{this.createdTopicUrl}} target="_blank" rel="noopener noreferrer">
              Voir la fiche
            </a>
          </div>
        {{/if}}

        {{#if this.results.length}}
          <div style="background: var(--primary-very-low); padding: 1em; border-radius: 8px;">
            <h3>Résultats de la recherche</h3>
            <div style="max-height: 400px; overflow-y: auto; margin-top: 0.5em;">
              {{#each this.results as |game|}}
                <div
                  role="button"
                  style="display: flex; align-items: center; gap: 1em; padding: 0.75em; cursor: pointer; border-radius: 6px; border: 1px solid var(--primary-low); margin-bottom: 0.5em; transition: background 0.2s; {{if (eq this.selectedGame.id game.id) 'background: var(--tertiary-low); border-color: var(--tertiary);'}}"
                  {{on "click" (fn this.loadGameDetails game.id)}}
                >
                  {{#if game.thumbnail}}
                    <img src={{game.thumbnail}} alt={{game.name}} width="60" style="border-radius: 4px; object-fit: cover;" />
                  {{/if}}
                  <div>
                    <strong>{{game.name}}</strong>
                    {{#if game.yearpublished}}
                      <span style="color: var(--primary-medium);"> ({{game.yearpublished}})</span>
                    {{/if}}
                  </div>
                  {{#if (eq this.selectedGame.id game.id)}}
                    <span style="margin-left: auto;">⬅️ Sélectionné</span>
                  {{/if}}
                </div>
              {{/each}}
            </div>
          </div>
        {{/if}}

        {{#if this.loading}}
          <div style="text-align: center; padding: 2em;">
            <p>Recherche en cours...</p>
          </div>
        {{/if}}

        {{#if this.loadingDetails}}
          <div style="text-align: center; padding: 2em;">
            <p>Chargement des détails...</p>
          </div>
        {{/if}}

        {{#if this.selectedGame}}
          <div style="background: var(--primary-very-low); padding: 1.5em; border-radius: 8px; margin-top: 1.5em;">
            <h2>{{this.selectedGame.name}}</h2>
            
            <div style="display: flex; gap: 1em; flex-wrap: wrap;">
              {{#if this.selectedGame.image}}
                <img src={{this.selectedGame.image}} alt={{this.selectedGame.name}} width="200" style="border-radius: 6px; object-fit: cover; flex-shrink: 0;" />
              {{/if}}
              <div style="flex: 1; min-width: 200px;">
                <p><strong>Note BGG :</strong> {{this.selectedGame.rating}} ⭐</p>
                <p><strong>Joueurs :</strong> {{this.selectedGame.minplayers}} - {{this.selectedGame.maxplayers}}</p>
                <p><strong>Durée :</strong> {{this.selectedGame.playingtime}} min</p>
                <p><strong>Âge :</strong> {{this.selectedGame.minage}}+</p>
                {{#if this.selectedGame.categories}}
                  <p><strong>Catégories :</strong> {{this.selectedGame.categories}}</p>
                {{/if}}
                {{#if this.selectedGame.mechanics}}
                  <p><strong>Mécanismes :</strong> {{this.selectedGame.mechanics}}</p>
                {{/if}}
              </div>
            </div>

            <div style="margin-top: 1em;">
              <p><strong>Description :</strong></p>
              <p>{{this.selectedGame.description}}</p>
            </div>

            {{!-- Sélection des images --}}
            {{#if this.selectedGame.images.length}}
              <div style="margin-top: 1.5em;">
                <h3>🖼️ Images disponibles</h3>
                <p style="font-size: 0.9em; color: var(--primary-medium);">Cliquez sur les images pour les sélectionner/déselectionner</p>
                <div style="display: flex; flex-wrap: wrap; gap: 0.5em;">
                  {{#each this.selectedGame.images as |imgUrl|}}
                    <div
                      role="button"
                      style="border: 3px solid {{if (this.isImageSelected imgUrl) 'var(--tertiary)' 'transparent'}}; cursor: pointer; padding: 2px; border-radius: 6px; transition: border 0.2s;"
                      {{on "click" (fn this.toggleImageSelection imgUrl)}}
                    >
                      <img src={{imgUrl}} width="150" style="border-radius: 3px; object-fit: cover;" />
                    </div>
                  {{/each}}
                </div>
              </div>
            {{/if}}

            {{!-- Sélection des vidéos --}}
            {{#if this.selectedGame.videos.length}}
              <div style="margin-top: 1.5em;">
                <h3>🎬 Vidéos disponibles</h3>
                <p style="font-size: 0.9em; color: var(--primary-medium);">Cliquez sur les vidéos pour les sélectionner/déselectionner</p>
                <div style="display: flex; flex-wrap: wrap; gap: 0.5em;">
                  {{#each this.selectedGame.videos as |video|}}
                    <div
                      role="button"
                      style="border: 3px solid {{if (this.isVideoSelected video.id) 'var(--tertiary)' 'transparent'}}; cursor: pointer; padding: 2px; border-radius: 6px; width: 230px; transition: border 0.2s;"
                      {{on "click" (fn this.toggleVideoSelection video.id)}}
                    >
                      <div style="text-align: center;">
                        <img src={{video.thumbnail}} width="220" style="border-radius: 3px;" />
                        <p style="font-size: 0.85em; margin: 0.3em 0; font-weight: bold;">{{video.title}}</p>
                        <p style="font-size: 0.75em; color: var(--primary-medium);">par {{video.author}}</p>
                      </div>
                    </div>
                  {{/each}}
                </div>
              </div>
            {{/if}}

            {{!-- Bouton de création --}}
            <div style="margin-top: 1.5em; text-align: center;">
              <DButton
                @label="Créer la fiche dans le forum"
                @action={{this.executeTopicCreation}}
                @disabled={{this.creatingTopic}}
                class="btn-primary btn-large"
              />
              {{#if this.creatingTopic}}
                <p style="margin-top: 0.5em;">Création en cours...</p>
              {{/if}}
            </div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
