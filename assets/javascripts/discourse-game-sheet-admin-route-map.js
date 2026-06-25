export default {
  model() {
    return this.api.adminPlugin("discourse-game-sheet");
  },

  setupController(controller, model) {
    controller.set("model", model);
  },
};
