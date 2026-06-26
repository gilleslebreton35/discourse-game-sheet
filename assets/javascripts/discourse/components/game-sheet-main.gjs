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
  @tracked videoUrl = ""; // Nouveau champ

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
    // Chargement des catégories
    const cats = await ajax("/game-sheet-api/categories");
    this.categories = cats;
  }

  <template>
    <div style="padding:20px; max-width: 800px; margin: auto;">
      <h1>Créateur de fiches</h1>
      <input type="text" placeholder="Taper pour chercher..." {{on "input" this.updateQuery}} style="width:100%; padding:10px; border-radius:5px; border:1px solid #ccc;" />

      {{!-- Liste de résultats --}}
      {{#each this.results as |game|}}
        <div style="padding:10px; border-bottom:1px solid #eee; display:flex; justify-content:space-between;">
           {{game.name}} 
           <button type="button" data-id={{game.id}} {{on "click" this.selectGame}}>Choisir</button>
        </div>
      {{/each}}

      {{#if this.selectedGame}}
        {{!-- C'est ici que l'on ajoute le style (carte grise) --}}
        <div style="margin-top:20px; padding:25px; border:1px solid #ddd; border-radius:10px; background-color:#f9f9f9;">
          
          <h2>{{this.selectedGame.name}}</h2>
          
          {{!-- Lien BGG --}}
          <a href="https://boardgamegeek.com/boardgame/{{this.selectedGame.id}}" target="_blank" style="color: #0088cc; font-weight: bold;">
            Voir la fiche originale sur BoardGameGeek
          </a>

          <div style="margin:15px 0; padding:10px; border-left: 4px solid #0088cc; background:white;">
            <p><strong>Joueurs:</strong> {{this.selectedGame.minplayers}} - {{this.selectedGame.maxplayers}}</p>
            <p><strong>Durée:</strong> {{this.selectedGame.playingtime}} min</p>
          </div>

          <h3>Description</h3>
          <div style="background:white; padding:15px; border-radius:5px;">
            {{{this.selectedGame.description}}}
          </div>

          {{!-- Champ Vidéo manuel --}}
          <h3 style="margin-top:20px;">Ajouter une vidéo (Lien YouTube)</h3>
          <input type="text" placeholder="Coller le lien ici..." style="width:100%; padding:10px;" />

          {{!-- Choix des catégories --}}
          <div style="margin-top:20px;">
            <label><strong>Catégorie :</strong></label>
            <select style="width:100%; padding:10px;">
              <option value="">Choisir la catégorie</option>
              {{#each this.categories as |cat|}}
                <option value={{cat.id}}>{{cat.name}}</option>
              {{/each}}
            </select>
          </div>
          
          <button style="margin-top:20px; width:100%; padding:15px; background:#0088cc; color:white; border:none; cursor:pointer;">
            Créer le sujet
          </button>
        </div>
      {{/if}}
    </div>
  </template>
}
