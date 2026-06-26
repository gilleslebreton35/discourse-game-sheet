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
    <div style="padding:20px; max-width: 800px;">
      <h1>Créateur de fiches</h1>
      <input type="text" placeholder="Taper pour chercher..." {{on "input" this.updateQuery}} style="width:100%; padding:10px; margin-bottom: 20px;" />

      {{!-- Liste de recherche --}}
      {{#each this.results as |game|}}
        <div style="display:flex; align-items:center; margin:10px 0; border-bottom:1px solid #eee; padding-bottom:5px;">
          <img src={{game.image}} width="50" style="margin-right:10px; border-radius:4px;" />
          <div style="flex-grow:1;">
            <strong>{{game.name}}</strong> ({{game.yearpublished}})
          </div>
          <button type="button" data-id={{game.id}} {{on "click" this.selectGame}}>Choisir</button>
        </div>
      {{/each}}

      {{#if this.selectedGame}}
        <div style="margin-top:40px; padding:30px; border:1px solid #ddd; border-radius:8px; background:#fff;">
          
          {{!-- Titre et Image --}}
          <h1 style="margin-top:0;">{{this.selectedGame.name}}</h1>
          {{#if this.selectedGame.image}}
            <img src={{this.selectedGame.image}} style="max-width:100%; height:auto; border-radius:8px;" />
          {{/if}}
          
          {{!-- Bloc Meta --}}
          <div style="background:#f4f4f4; padding:15px; margin:20px 0; border-radius:5px; font-weight:bold;">
             👤 Joueurs : {{this.selectedGame.min_players}}-{{this.selectedGame.max_players}} | 
             ⏳ Durée : {{this.selectedGame.playing_time}} min | 
             🎂 Âge : {{this.selectedGame.min_age}}+
          </div>

          {{!-- Description --}}
          <h2>📖 Description</h2>
          <div style="line-height:1.6;">
            {{{this.selectedGame.description}}}
          </div>

          {{!-- Vidéos --}}
          {{#if this.selectedGame.videos}}
            <h2>🎥 Vidéos</h2>
            <ul>
              {{#each this.selectedGame.videos as |video|}}
                <li><a href={{video.link}} target="_blank">{{video.title}}</a></li>
              {{/each}}
            </ul>
          {{/if}}

          <hr style="margin: 30px 0;">

          {{!-- Sélection catégorie --}}
          <label><strong>Catégorie pour le topic :</strong></label><br>
          <select {{on "change" this.updateCategory}} value={{this.destinationCategory}} style="width:100%; padding:10px; margin:10px 0;">
            <option value="">Choisir une catégorie</option>
            {{#each this.categories as |cat|}}
              <option value={{cat.id}}>{{cat.name}}</option>
            {{/each}}
          </select>

          <button type="button" style="width:100%; padding:15px; background: #0088cc; color:white; border:none; border-radius:5px; cursor:pointer;" {{on "click" this.submitTopic}}>
            Créer le sujet
          </button>
        </div>
      {{/if}}
    </div>
  </template>
