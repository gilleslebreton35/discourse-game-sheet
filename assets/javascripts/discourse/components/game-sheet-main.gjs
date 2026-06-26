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
      <input type="text" placeholder="Rechercher..." value={{this.query}} {{on "input" this.updateQuery}} style="width:100%; padding:10px; margin-bottom:20px;" />

      {{#each this.results as |game|}}
        <div style="padding:10px; border-bottom:1px solid #eee; display:flex; align-items:center; gap:10px;">
          <img src={{game.thumbnail}} style="width:50px; height:50px; object-fit:cover;" />
          <strong style="flex:1">{{game.name}}</strong>
          <button type="button" data-id={{game.id}} {{on "click" this.selectGame}} class="btn">Choisir</button>
        </div>
      {{/each}}

      {{#if this.selectedGame}}
        <div style="margin-top:20px; padding:20px; border:1px solid #ddd; background:#f9f9f9;">
          <h2>{{this.selectedGame.name}}</h2>
          
          <h3>Vidéos</h3>
          <div style="display:flex; gap:10px; margin-bottom:10px;">
            <select {{on "change" this.updateLanguage}}>
              <option value="ALL">Toutes langues</option>
              <option value="French">Français</option>
              <option value="English">Anglais</option>
            </select>
            <select {{on "change" this.updateCategoryFilter}}>
              <option value="ALL">Toutes catégories</option>
              <option value="instructional">Règles</option>
              <option value="review">Critiques</option>
              <option value="session">Parties</option>
            </select>
          </div>

          <div style="margin-top:10px; max-height:200px; overflow-y:auto;">
            {{#each this.filteredVideos as |video|}}
              <label style="display:block;">
                <input type="checkbox" checked={{this.isFieldChecked video.link}} {{on "change" (fn this.toggleVideo video)}} />
                {{video.title}} ({{video.language}})
              </label>
            {{/each}}
          </div>

          <select {{on "change" this.setCategory}} style="width:100%; margin:20px 0;">
            <option value="">-- Catégorie destination --</option>
            {{#each this.categories as |cat|}} <option value={{cat.id}}>{{cat.name}}</option> {{/each}}
          </select>

          <button type="button" {{on "click" this.createTopic}} class="btn btn-primary" disabled={{this.creating}}>
            {{if this.creating "Création..." "🚀 Créer le sujet"}}
          </button>
        </div>
      {{/if}}
    </div>
  </template>
}
