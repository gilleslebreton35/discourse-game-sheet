import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsGameSheetController extends Controller {
  @tracked query = "";
  @tracked results = [];
  @tracked loading = false;
  @tracked creatingId = null;
  @tracked createdTopicUrl = null;
  @tracked error = null;

  @action
  updateQuery(event) {
    this.query = event.target.value;
  }

  @action
  async searchGames() {
    this.loading = true;
    this.error = null;
    this.createdTopicUrl = null;

    try {
      const response = await ajax(`/game-sheet/search?q=${encodeURIComponent(this.query)}`);
      this.results = response.results || [];
    } catch (e) {
      this.error = e?.jqXHR?.responseJSON?.errors?.join(", ") || e.message || "Search failed";
      this.results = [];
    } finally {
      this.loading = false;
    }
  }

  @action
  async createTopic(gameId) {
    this.creatingId = gameId;
    this.error = null;
    this.createdTopicUrl = null;

    try {
      const response = await ajax("/game-sheet/create-topic", {
        type: "POST",
        data: { game_id: gameId },
      });

      this.createdTopicUrl = response.topic_url;
    } catch (e) {
      this.error = e?.jqXHR?.responseJSON?.errors?.join(", ") || e.message || "Topic creation failed";
    } finally {
      this.creatingId = null;
    }
  }
}
