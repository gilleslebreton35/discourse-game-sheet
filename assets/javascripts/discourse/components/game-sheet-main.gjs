import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";

export default class GameSheetMain extends Component {
  @tracked query = "";
  @tracked results = [];
  @tracked filteredResults = [];
  @tracked selectedGame = null;
  @tracked categories = [];
  @tracked destinationCategory = "";
  @tracked includeImage = true;
  @tracked selectedImages = [];
  @tracked selectedVideos = [];
  @tracked loading = false;
  @tracked creating = false;
  @tracked searchLimit = 10;

  get displayResults() {
    return this.filteredResults.slice(0, this.searchLimit);
  }

  get hasMore() {
    return this.filteredResults.length > this.searchLimit;
  }

  get remaining() {
    return this.filteredResults.length - this.searchLimit;
  }

  @action
  updateQuery(event) {
    this.query = event.target.value;
    this.searchLimit = 10;
    discourseDebounce(this, this.performSearch, 500);
  }

  @action
  async performSearch() {
    if (this.query.length < 3) return;
    this.loading = true;
    try {
      const res = await ajax(`/game-sheet-api/search?q=${encodeURIComponent(this.query)}`);
      this.results = res.bgg || [];
      this.filteredResults = this.results;
    } catch(e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  expandSearch() {
    this.searchLimit = this.searchLimit + 20;
  }

  @action
  async selectGame(event) {
    const gameId = event.currentTarget.dataset.id;
    this.selectedGame = await ajax(`/game-sheet-api/details/${gameId}`);
    this.selectedImages = [];
    this.selectedVideos = [];
    
    try {
      const cats = await ajax("/game-sheet-api/categories");
      this.categories = cats;
    } catch(e) {
      this.categories = [];
    }
  }

  @action
  toggleImage(imgUrl) {
    if (this.selectedImages.includes(imgUrl)) {
      this.selectedImages = this.selectedImages.filter(i => i !== imgUrl);
    } else {
      this.selectedImages = [...this.selectedImages, imgUrl];
    }
  }

  @action
  addVideo(event) {
    const input = event.currentTarget.closest("div").querySelector('input[type="text"]');
    const url = input.value.trim();
    if (url && !this.selectedVideos.includes(url)) {
      this.selectedVideos = [...this.selectedVideos, url];
    }
    input.value = "";
  }

  @action
  removeVideo(url) {
    this.selectedVideos = this.selectedVideos.filter(v => v !== url);
  }

  @action
  updateCategory(event) {
    this.destinationCategory = event.target.value;
  }

  @action
  toggleIncludeImage(event) {
    this.includeImage = event.target.checked;
  }

  @action
  async createTopic() {
    if (!this.destinationCategory) {
      alert("Veuillez sélectionner une catégorie");
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
          selected_images: JSON.stringify(this.selectedImages),
          selected_videos: this.selectedVideos.join("|")
        }
      });
      window.location.href = res.topic_url;
    } catch(e) {
      popupAjaxError(e);
    } finally {
      this.creating = false;
    }
  }

  <template>
    <div style="padding:20px; max-width: 900px; margin: auto;">
      <h1>Créateur de fiches de jeux</h1>
      
      <div style="display:flex; gap:10px; margin-bottom:20px;">
        <input type="text" placeholder="Rechercher un jeu..." 
               value={{this.query}}
               {{on "input" this.updateQuery}}
               style="flex:1; padding:10px; border-radius:5px; border:1px solid #ccc;" />
      </div>

      {{#if this.loading}}
        <p>Recherche en cours...</p>
      {{/if}}

      {{#if this.filteredResults.length}}
        {{#each this.displayResults as |game|}}
          <div style="padding:10px; border-bottom:1px solid #eee; display:flex; align-items:center; gap:15px;">
            {{! Image du jeu à gauche }}
            <div style="width:60px; height:60px; flex-shrink:0; border-radius:5px; overflow:hidden; background:#f0f0f0; display:flex; align-items:center; justify-content:center;">
              {{#if game.thumbnail}}
                <img src={{game.thumbnail}} alt="" 
                     style="width:100%; height:100%; object-fit:cover;" />
              {{else}}
                <span style="font-size:24px; color:#ccc;">🎲</span>
              {{/if}}
            </div>
            {{! Infos du jeu }}
            <div style="flex:1;">
              <strong>{{game.name}}</strong>
              {{#if game.yearpublished}}
                <span style="color:#888; margin-left:8px;">({{game.yearpublished}})</span>
              {{/if}}
            </div>
            {{! Bouton Choisir }}
            <button type="button" data-id={{game.id}} {{on "click" this.selectGame}} 
                    class="btn btn-primary btn-small">
              Choisir
            </button>
          </div>
        {{/each}}

        {{! Bouton pour élargir la recherche }}
        {{#if this.hasMore}}
          <div style="text-align:center; margin-top:15px;">
            <button type="button" {{on "click" this.expandSearch}} 
                    class="btn btn-default">
              🔍 Afficher plus de résultats ({{this.remaining}} supplémentaires)
            </button>
          </div>
        {{/if}}
      {{/if}}

      {{#if this.selectedGame}}
        <div style="margin-top:20px; padding:25px; border:1px solid #ddd; border-radius:10px; background-color:#f9f9f9;">
          
          <div style="display:flex; gap:20px;">
            {{#if this.selectedGame.image}}
              <img src={{this.selectedGame.image}} alt={{this.selectedGame.name}} 
                   style="width:200px; height:auto; border-radius:5px; object-fit:cover;" />
            {{/if}}
            <div style="flex:1;">
              <h2>{{this.selectedGame.name}}</h2>
              <a href="https://boardgamegeek.com/boardgame/{{this.selectedGame.id}}" target="_blank" 
                 style="color: #0088cc;">
                Voir sur BoardGameGeek →
              </a>
              <div style="margin:15px 0; padding:10px; border-left: 4px solid #0088cc; background:white;">
                <p><strong>Joueurs:</strong> {{this.selectedGame.minplayers}}-{{this.selectedGame.maxplayers}}</p>
                <p><strong>Durée:</strong> {{this.selectedGame.playingtime}} min</p>
                <p><strong>Âge:</strong> {{this.selectedGame.minage}}+</p>
              </div>
            </div>
          </div>

          <h3>Description</h3>
          <div style="background:white; padding:15px; border-radius:5px; max-height:300px; overflow-y:auto;">
            {{{this.selectedGame.description}}}
          </div>

          {{#if this.selectedGame.images.length}}
            <h3 style="margin-top:20px;">Images du jeu</h3>
            <div style="display:flex; flex-wrap:wrap; gap:10px;">
              {{#each this.selectedGame.images as |imgUrl|}}
                <div style="position:relative; cursor:pointer;" {{on "click" (fn this.toggleImage imgUrl)}}>
                  <img src={{imgUrl}} alt="" 
                       style="width:120px; height:120px; object-fit:cover; border-radius:5px;" />
                </div>
              {{/each}}
            </div>
          {{/if}}

          <h3 style="margin-top:20px;">Ajouter une vidéo YouTube</h3>
          <div style="display:flex; gap:10px;">
            <input type="text" placeholder="Coller le lien YouTube ici..." 
                   style="flex:1; padding:10px; border-radius:5px; border:1px solid #ccc;" />
            <button type="button" {{on "click" this.addVideo}} class="btn">Ajouter</button>
          </div>

       {{#if this.selectedGame.videos.length}}
            <h3 style="margin-top:20px;">Choisir les vidéos (Français uniquement)</h3>
            <div style="background:white; padding:10px; border-radius:5px; border:1px solid #ddd;">
              {{#each this.selectedGame.videos as |video|}}
                <label style="display:block; margin-bottom:5px;">
                  <input type="checkbox" 
                         checked={{this.isFieldChecked video.link}} 
                         {{on "change" (fn this.toggleVideo video)}} />
                  {{video.title}}
                </label>
              {{/each}}
            </div>
          {{/if}}

          <div style="margin-top:20px; padding:15px; background:white; border-radius:5px;">
            <h4>Options du sujet</h4>
            
            <label style="display:block; margin-bottom:10px;">
              <input type="checkbox" checked={{this.includeImage}} {{on "change" this.toggleIncludeImage}} />
              Inclure l'image principale
            </label>

            <label style="display:block; margin-bottom:10px;">
              <strong>Catégorie :</strong>
              <select {{on "change" this.updateCategory}} style="width:100%; padding:10px; margin-top:5px;">
                <option value="">-- Choisir la catégorie --</option>
                {{#each this.categories as |cat|}}
                  <option value={{cat.id}}>
                    {{cat.name}}
                  </option>
                {{/each}}
              </select>
            </label>
          </div>

          <button type="button" {{on "click" this.createTopic}} 
                  class="btn btn-primary" 
                  disabled={{this.creating}}
                  style="margin-top:20px; width:100%; padding:15px; font-size:1.2em;">
            {{#if this.creating}}
              Création en cours...
            {{else}}
              🚀 Créer le sujet
            {{/if}}
          </button>
        </div>
      {{/if}}
    </div>
  </template>
}
