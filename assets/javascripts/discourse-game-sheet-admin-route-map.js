export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("game-sheet", { path: "/game-sheet" });
  }
};
