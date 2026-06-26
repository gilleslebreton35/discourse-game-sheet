import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { debounce } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { fn } from "@ember/helper";

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
    debounce(this, this.performSearch, 500); // 500ms d'attente
  }

  async performSearch() {
    if (this.query.length < 3) return;
    const res = await ajax(`/game-sheet-api/search?q=${encodeURIComponent(this.query)}`);
    this.results = res.bgg || [];
  }

  @action
  async selectGame(gameId) {
    this.selectedGame = await ajax(`/game-sheet-api/details/${gameId}`);
    this.categories = await ajax("/game-sheet-api/categories");
  }

  @action
  toggleSelection(array, item) {
    if (array.includes(item)) {
      return array.filter(i => i !== item);
    } else {
      return [...array, item];
    }
  }

  @action
  async submitTopic() {
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
          {{game.name}} <button {{on "click" (fn this.selectGame game.id)}}>Choisir</button>
        </div>
      {{/each}}

      {{#if this.selectedGame}}
        <div style="margin-top:20px; border-top:1px solid #ccc;">
          <h3>Images :</h3>
          {{#each this.selectedGame.images as |img|}}
            <label><input type="checkbox" {{on "change" (fn (mut this.selectedImages) (this.toggleSelection this.selectedImages img))}} /> <img src={{img}} width="50"/></label>
          {{/each}}

          <h3>Vidéos :</h3>
          {{#each this.selectedGame.videos as |vid|}}
            <label><input type="checkbox" {{on "change" (fn (mut this.selectedVideos) (this.toggleSelection this.selectedVideos vid))}} /> {{vid.title}}</label>
          {{/each}}

          <select {{on "change" (fn (mut this.destinationCategory) target.value)}}>
            <option value="">Choisir la catégorie</option>
            {{#each this.categories as |cat|}}
              <option value={{cat.id}}>{{cat.name}}</option>
            {{/each}}
          </select>

          <button {{on "click" this.submitTopic}}>Créer le sujet</button>
        </div>
      {{/if}}
    </div>
  </template>
}
