import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { debounce } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";

export default class GameSheetMain extends Component {
  @tracked query = "";
  @tracked results = [];
  @tracked selectedGame = null;
  @tracked selectedImages = [];
  @tracked selectedVideos = [];
  @tracked categories = [];
  @tracked destinationCategory = "";

  @action
  updateQuery(event) {
    this.query = event.target.value;
    debounce(this, this.performSearch, 500);
  }

  async performSearch() {
    if (this.query.length < 3) return;
    const res = await ajax(`/game-sheet-api/search?q=${encodeURIComponent(this.query)}`);
    this.results = res.bgg || [];
  }

  @action
  async selectGame(event) {
    const gameId = event.target.dataset.id;
    this.selectedGame = await ajax(`/game-sheet-api/details/${gameId}`);
    this.categories = await ajax("/game-sheet-api/categories");
  }

  @action
  toggleImage(event) {
    const img = event.target.dataset.img;
    if (event.target.checked) {
      this.selectedImages = [...this.selectedImages, img];
    } else {
      this.selectedImages = this.selectedImages.filter(i => i !== img);
    }
  }

  @action
  toggleVideo(event) {
    const vid = event.target.dataset.vid;
    if (event.target.checked) {
      this.selectedVideos = [...this.selectedVideos, vid];
    } else {
      this.selectedVideos = this.selectedVideos.filter(v => v !== vid);
    }
  }

  @action
  updateCategory(event) {
    this.destinationCategory = event.target.value;
  }

  @action
  async submitTopic() {
    if (!this.selectedGame) return;
    const res = await ajax("/game-sheet-api/create-topic", {
      type: "POST",
      data: {
        game_id: this.selectedGame.id,
        category_id: this.destinationCategory,
        images: this.selectedImages,
        videos: this.selectedVideos
      }
    });
    window.location.href = res.topic_url;
  }

  <template>
    <div style="padding:20px;">
      <h1>Créateur de fiches</h1>
      <input type="text" placeholder="Taper pour chercher..." {{on "input" this.updateQuery}} />

      {{#each this.results as |game|}}
        <div style="margin:10px 0;">
          {{game.name}} 
          <button type="button" data-id={{game.id}} {{on "click" this.selectGame}}>Choisir</button>
        </div>
      {{/each}}

      {{#if this.selectedGame}}
        <div style="margin-top:20px; border-top:1px solid #ccc;">
          <h3>Images :</h3>
          {{#each this.selectedGame.images as |img|}}
            <label>
              <input type="checkbox" data-img={{img}} {{on "change" this.toggleImage}} /> 
              <img src={{img}} width="50" alt="game-art"/>
            </label>
          {{/each}}

          <h3>Vidéos :</h3>
          {{#each this.selectedGame.videos as |vid|}}
            <label>
              <input type="checkbox" data-vid={{vid.title}} {{on "change" this.toggleVideo}} /> 
              {{vid.title}}
            </label>
          {{/each}}

          <select {{on "change" this.updateCategory}}>
            <option value="">Choisir la catégorie</option>
            {{#each this.categories as |cat|}}
              <option value={{cat.id}}>{{cat.name}}</option>
            {{/each}}
          </select>

          <button type="button" {{on "click" this.submitTopic}}>Créer le sujet</button>
        </div>
      {{/if}}
    </div>
  </template>
}
