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
  @tracked categories = [];
  @tracked destinationCategory = "";

  @action
  updateQuery(event) {
    this.query = event.target.value;
    debounce(this, this.performSearch, 500);
  }

  @action
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
  updateCategory(event) {
    this.destinationCategory = event.target.value;
  }

  @action
  async submitTopic() {
    if (!this.selectedGame || !this.destinationCategory) {
      alert("Veuillez sélectionner un jeu et une catégorie !");
      return;
    }
    const res = await ajax("/game-sheet-api/create-topic", {
      type: "POST",
      data: {
        game_id: this.selectedGame.id,
        category_id: this.destinationCategory
      }
    });
    window.location.href = res.topic_url;
  }

  <template>
    <div style="padding:20px;">
      <h1>Créateur de fiches</h1>
      <input type="text" placeholder="Taper pour chercher..." {{on "input" this.updateQuery}} />

      {{#each this.results as |game|}}
        <div style="display:flex; align-items:center; margin:10px 0; border-bottom:1px solid #eee;">
          <img src={{game.image}} width="50" style="margin-right:10px;" alt="vignette" />
          <div style="flex-grow:1;">
            <strong>{{game.name}}</strong> ({{game.yearpublished}})
          </div>
          <button type="button" data-id={{game.id}} {{on "click" this.selectGame}}>Choisir</button>
        </div>
      {{/each}}

      {{#if this.selectedGame}}
        <div style="margin-top:20px; padding:20px; border:1px solid #ccc;">
          <h2>{{this.selectedGame.name}}</h2>
          
          {{!-- Nouvel affichage des infos techniques --}}
          <div style="background:#f4f4f4; padding:10px; margin-bottom:15px; border-radius:5px;">
             <strong>Joueurs :</strong> {{this.selectedGame.min_players}} - {{this.selectedGame.max_players}}<br>
             <strong>Durée :</strong> {{this.selectedGame.playing_time}} minutes<br>
             <strong>Âge :</strong> {{this.selectedGame.min_age}}+ ans
          </div>

          {{#if this.selectedGame.image}}
            <img src={{this.selectedGame.image}} width="300" alt="game-cover" />
          {{/if}}
          
          <div style="margin: 15px 0;">
            {{{this.selectedGame.description}}}
          </div>

          <label>Catégorie :</label>
          <select {{on "change" this.updateCategory}} value={{this.destinationCategory}}>
            <option value="">Choisir une catégorie</option>
            {{#each this.categories as |cat|}}
              <option value={{cat.id}}>{{cat.name}}</option>
            {{/each}}
          </select>

          <button type="button" style="margin-left:10px;" {{on "click" this.submitTopic}}>Créer le sujet</button>
        </div>
      {{/if}}
    </div>
  </template>
}
