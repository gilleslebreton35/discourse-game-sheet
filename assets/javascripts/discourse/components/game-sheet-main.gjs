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
  @tracked selectedGame = null;
  @tracked categories = [];
  @tracked destinationCategory = "";
  @tracked selectedVideos = [];
  @tracked creating = false;
  
  @tracked languageFilter = "ALL";
  @tracked categoryFilter = "ALL";

  get filteredVideos() {
    if (!this.selectedGame?.videos) return [];
    return this.selectedGame.videos.filter(v => {
      const matchesLang = (this.languageFilter === "ALL" || v.language === this.languageFilter);
      const matchesCat = (this.categoryFilter === "ALL" || v.category === this.categoryFilter);
      return matchesLang && matchesCat;
    });
  }

  @action
  setCategory(event) {
    this.destinationCategory = event.target.value;
  }

  @action
  updateLanguage(event) { this.languageFilter = event.target.value; }

  @action
  updateCategoryFilter(event) { this.categoryFilter = event.target.value; }

  @action
  updateQuery(event) {
    this.query = event.target.value;
    discourseDebounce(this, this.performSearch, 500);
  }

  @action
  async performSearch() {
    if (this.query.length < 3) return;
    this.loading = true;
    try {
      const res = await ajax(`/game-sheet-api/search?q=${encodeURIComponent(this.query)}`);
      this.results = res.bgg || [];
    } catch(e) { popupAjaxError(e); } finally { this.loading = false; }
  }

  @action
  async selectGame(event) {
    const gameId = event.currentTarget.dataset.id;
    this.selectedGame = await ajax(`/game-sheet-api/details/${gameId}`);
    this.selectedVideos = [];
    try { this.categories = await ajax("/game-sheet-api/categories"); } catch(e) { this.categories = []; }
  }

  @action
  isFieldChecked(link) { return this.selectedVideos.some(v => v.link === link); }

  @action
  toggleVideo(video, event) {
    if (event.target.checked) {
      this.selectedVideos = [...this.selectedVideos, video];
    } else {
      this.selectedVideos = this.selectedVideos.filter(v => v.link !== video.link);
    }
  }

  @action
  async createTopic() {
    if (!this.destinationCategory) { alert("Choisissez une catégorie"); return; }
    this.creating = true;
    try {
      const res = await ajax("/game-sheet-api/create-topic", {
        type: "POST",
        data: {
          game_id: this.selectedGame.id,
          category_id: this.destinationCategory,
          selected_videos: JSON.stringify(this.selectedVideos)
        }
      });
      window.location.href = res.topic_url;
    } catch(e) { popupAjaxError(e); } finally { this.creating = false; }
  }

  <template>
    <div style="padding:20px; max-width: 900px; margin: auto;">
      <h1>Créateur de fiches de jeux</h1>
      <input type="text" placeholder="Rechercher un jeu..." value={{this.query}} {{on "input" this.updateQuery}} style="width:100%; padding:10px; margin-bottom:20px; font-size:16px;" />

      {{#each this.results as |game|}}
        <div style="padding:10px; border-bottom:1px solid #eee; display:flex; align-items:center; gap:10px;">
          <img src={{game.thumbnail}} style="width:50px; height:50px; object-fit:cover; border-radius:4px;" />
          <strong style="flex:1">{{game.name}}</strong>
          <button type="button" data-id={{game.id}} {{on "click" this.selectGame}} class="btn">Choisir</button>
        </div>
      {{/each}}

      {{#if this.selectedGame}}
        <div style="margin-top:20px; padding:20px; border:1px solid #ddd; background:#f9f9f9; border-radius:8px;">
          
          {{! EN-TÊTE DU JEU }}
          <div style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 30px; background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
            {{#if this.selectedGame.image}}
              <img src={{this.selectedGame.image}} style="width: 220px; max-height: 250px; object-fit: contain; border-radius: 4px;" />
            {{/if}}
            <div style="flex: 1; min-width: 280px;">
              <h2 style="margin-top: 0;">{{this.selectedGame.name}}</h2>
              <div style="margin-bottom: 15px; font-weight: bold; color: #444; background: #f0f0f0; padding: 10px; border-radius: 5px; display: inline-block;">
                👤 {{this.selectedGame.minplayers}}-{{this.selectedGame.maxplayers}} joueurs &nbsp;|&nbsp; 
                ⏳ {{this.selectedGame.playingtime}} min &nbsp;|&nbsp; 
                🎂 {{this.selectedGame.minage}}+ ans
              </div>
              <div style="max-height: 130px; overflow-y: auto; font-size: 0.95em; color: #333; white-space: pre-wrap; padding-right: 10px;">
                {{this.selectedGame.description}}
              </div>
            </div>
          </div>
          
          <h3>Vidéos</h3>
          <div style="display:flex; gap:10px; margin-bottom:15px;">
            <select {{on "change" this.updateLanguage}} style="padding: 8px; border-radius: 4px; border: 1px solid #ccc;">
              <option value="ALL">Toutes langues</option>
              <option value="French">Français</option>
              <option value="English">Anglais</option>
            </select>
            <select {{on "change" this.updateCategoryFilter}} style="padding: 8px; border-radius: 4px; border: 1px solid #ccc;">
              <option value="ALL">Toutes catégories</option>
              <option value="instructional">Règles</option>
              <option value="review">Critiques</option>
              <option value="session">Parties</option>
            </select>
          </div>

          {{! GRILLE DES VIDÉOS }}
          <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 15px; max-height: 500px; overflow-y: auto; padding-right: 10px; margin-bottom: 30px;">
            {{#each this.filteredVideos as |video|}}
              <label style="display: block; border: 2px solid {{if (this.isFieldChecked video.link) '#2196F3' 'transparent'}}; border-radius: 6px; overflow: hidden; background: {{if (this.isFieldChecked video.link) '#e3f2fd' '#fff'}}; cursor: pointer; transition: 0.2s; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
                {{#if video.thumbnail}}
                  <img src={{video.thumbnail}} style="width: 100%; aspect-ratio: 16/9; object-fit: cover; display: block;" />
                {{else}}
                  <div style="width: 100%; aspect-ratio: 16/9; background: #eee; display: flex; align-items: center; justify-content: center; color: #999;">Sans aperçu</div>
                {{/if}}
                
                <div style="padding: 12px;">
                  <div style="display: flex; gap: 8px; align-items: flex-start; margin-bottom: 8px;">
                    <input type="checkbox" checked={{this.isFieldChecked video.link}} {{on "change" (fn this.toggleVideo video)}} style="margin-top: 2px; flex-shrink: 0;" />
                    <strong style="font-size: 0.9em; line-height: 1.3; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;" title={{video.title}}>
                      {{video.title}}
                    </strong>
                  </div>
                  <div style="display: flex; justify-content: space-between; font-size: 0.75em; color: #666; margin-left: 22px; text-transform: uppercase; font-weight: bold;">
                    <span>{{video.language}}</span>
                    <span>{{video.category}}</span>
                  </div>
                </div>
              </label>
            {{/each}}
          </div>

          <hr style="margin: 30px 0; border: 0; border-top: 1px solid #ddd;" />

          <select {{on "change" this.setCategory}} style="width:100%; margin:20px 0; padding:10px;">
            <option value="">-- Catégorie destination --</option>
            {{#each this.categories as |cat|}} <option value={{cat.id}}>{{cat.name}}</option> {{/each}}
          </select>

          <button type="button" {{on "click" this.createTopic}} class="btn btn-primary" style="width:100%; padding: 15px; font-size: 16px;" disabled={{this.creating}}>
            {{if this.creating "Création..." "🚀 Créer le sujet"}}
          </button>
        </div>
      {{/if}}
    </div>
  </template>
}
