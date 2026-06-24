import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

export default class GameSheetNewController extends Controller {
  @service router;
  @service currentUser;

  @tracked query = "";
  @tracked results = [];
  @tracked loading = false;
  @tracked selectedGame = null;
  @tracked allowedCategories = [];
  @tracked selectedCategoryId = null;
  @tracked creating = false;
  @tracked error = null;

  constructor() {
    super(...arguments);
    this.loadCategories();
  }

  async loadCategories() {
    const idsSetting = settings.game_sheet_allowed_category_ids || "";
    const allowedIds = idsSetting
      .split("|")
      .map((x) => parseInt(x, 10))
      .filter(Boolean);

    const categories = this.site.categories || [];
    this.allowedCategories = allowedIds.length
      ? categories.filter((c) => allowedIds.includes(c.id))
      : categories.filter((c) => !c.read_restricted);
  }

  @action
  async search() {
    this.loading = true;
    this.error = null;

    try {
      const response = await ajax(`/game-sheet/search?q=${encodeURIComponent(this.query)}`);
      this.results = response.results || [];
    } catch (e) {
      this.error = "Erreur lors de la recherche BGG.";
    } finally {
      this.loading = false;
    }
  }

  @action
  async chooseGame(game) {
    this.loading = true;
    this.error = null;

    try {
      const response = await ajax(`/game-sheet/game/${game.id}`);
      this.selectedGame = response;
    } catch (e) {
      this.error = "Erreur lors du chargement du jeu.";
    } finally {
      this.loading = false;
    }
  }

  @action
  updateQuery(e) {
    this.query = e.target.value;
  }

  @action
  updateCategory(e) {
    this.selectedCategoryId = parseInt(e.target.value, 10);
  }

  @action
  async createTopic() {
    if (!this.selectedGame || !this.selectedCategoryId) {
      this.error = "Choisis un jeu et une catégorie.";
      return;
    }

    this.creating = true;
    this.error = null;

    try {
      const response = await ajax("/game-sheet/create-topic", {
        type: "POST",
        data: {
          title: this.selectedGame.name,
          category_id: this.selectedCategoryId,
          game: this.selectedGame,
        },
      });

      if (response?.topic_url) {
        this.router.transitionTo("topic", response.topic_slug, response.topic_id);
      }
    } catch (e) {
      this.error = "Erreur lors de la création du sujet.";
    } finally {
      this.creating = false;
    }
  }
}