import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";

export default class AdminGameSheet extends Component {
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
  isSelectedGame(gameId) {
    return this.selectedGame?.id === gameId;
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
    <div class="admin-container">
      <h1>Créer une fiche de jeu BGG</h1>

      <div style="margin: 1em 0;">
        <label>Rechercher un jeu :</label>
        <div style="display: flex; gap: 0.5em; margin-top: 0.5em;">
          <input
            type="text"
            value={{this.query}}
            {{on "input" this.updateQuery}}
            placeholder="Nom du jeu (ex: Catan, 7 Wonders...)"
            class="input-xxlarge"
          />
          <DButton
            @label="Rechercher"
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
        <table class="table">
          <thead>
            <tr>
              <th></th>
              <th>Nom</th>
              <th>Année</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each this.results as |game|}}
              <tr>
                <td>
                  {{#if game.thumbnail}}
                    <img src={{game.thumbnail}} alt={{game.name}} width="50" style="border-radius: 4px;" />
                  {{/if}}
                </td>
                <td>{{game.name}}</td>
                <td>{{game.yearpublished}}</td>
                <td>
                  <DButton
                    @label="Sélectionner"
                    @action={{fn this.loadGameDetails game.id}}
                    class="btn-primary"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else if this.loading}}
        <p>Recherche en cours...</p>
      {{/if}}

      {{#if this.selectedGame}}
        <div style="margin-top: 1em; padding: 1em; border: 1px solid var(--primary-low); border-radius: 8px;">
          <div style="display: flex; gap: 1em; flex-wrap: wrap;">
            {{#if this.selectedGame.image}}
              <div style="flex-shrink: 0;">
                <img src={{this.selectedGame.image}} alt={{this.selectedGame.name}} width="150" style="border-radius: 4px; object-fit: cover;" />
              </div>
            {{/if}}
            <div style="flex: 1; min-width: 200px;">
              <h2>{{this.selectedGame.name}}</h2>
              <p><strong>Note BGG :</strong> {{this.selectedGame.rating}}</p>
              <p><strong>Joueurs :</strong> {{this.selectedGame.minplayers}} - {{this.selectedGame.maxplayers}}</p>
              <p><strong>Durée :</strong> {{this.selectedGame.playingtime}} min</p>
              <p><strong>Âge :</strong> {{this.selectedGame.minage}}+</p>
              {{#if this.selectedGame.categories}}
                <p><strong>Catégories :</strong> {{this.selectedGame.categories}}</p>
              {{/if}}
              {{#if this.selectedGame.mechanics}}
                <p><strong>Mécanismes :</strong> {{this.selectedGame.mechanics}}</p>
              {{/if}}
              <p><strong>Description :</strong></p>
              <p>{{this.selectedGame.description}}</p>
            </div>
          </div>

          {{#if this.selectedGame.images.length}}
            <h3 style="margin-top: 1em;">Images disponibles</h3>
            <p style="font-size: 0.9em; color: var(--primary-medium);">Cliquez pour sélectionner/déselectionner</p>
            <div style="display: flex; flex-wrap: wrap; gap: 0.5em;">
              {{#each this.selectedGame.images as |imgUrl|}}
                <div
                  role="button"
                  style="border: 3px solid {{if (this.isImageSelected imgUrl) 'var(--tertiary)' 'transparent'}}; cursor: pointer; padding: 2px; border-radius: 4px;"
                  {{on "click" (fn this.toggleImageSelection imgUrl)}}
                >
                  <img src={{imgUrl}} width="150" style="border-radius: 2px;" />
                </div>
              {{/each}}
            </div>
          {{/if}}

          {{#if this.selectedGame.videos.length}}
            <h3 style="margin-top: 1em;">Vidéos disponibles</h3>
            <p style="font-size: 0.9em; color: var(--primary-medium);">Cliquez pour sélectionner/déselectionner</p>
            <div style="display: flex; flex-wrap: wrap; gap: 0.5em;">
              {{#each this.selectedGame.videos as |video|}}
                <div
                  role="button"
                  style="border: 3px solid {{if (this.isVideoSelected video.id) 'var(--tertiary)' 'transparent'}}; cursor: pointer; padding: 2px; border-radius: 4px; width: 230px;"
                  {{on "click" (fn this.toggleVideoSelection video.id)}}
                >
                  <div style="text-align: center;">
                    <img src={{video.thumbnail}} width="220" style="border-radius: 2px;" />
                    <p style="font-size: 0.85em; margin: 0.3em 0; font-weight: bold;">{{video.title}}</p>
                    <p style="font-size: 0.75em; color: var(--primary-medium);">par {{video.author}}</p>
                  </div>
                </div>
              {{/each}}
            </div>
          {{/if}}

          <div style="margin-top: 1em;">
            <DButton
              @label="Créer la fiche"
              @action={{this.executeTopicCreation}}
              @disabled={{this.creatingTopic}}
              class="btn-primary"
            />
          </div>
        </div>
      {{else if this.loadingDetails}}
        <p>Chargement des détails...</p>
      {{/if}}
    </div>
  </template>
}
