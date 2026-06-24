import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class GameSheetRoute extends Route {
  @service currentUser;

  beforeModel(transition) {
    if (!this.currentUser) {
      transition.abort();
      this.transitionTo("login");
    }
  }
}
