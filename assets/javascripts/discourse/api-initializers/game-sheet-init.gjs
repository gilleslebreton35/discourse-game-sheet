import { apiInitializer } from "discourse/lib/api";
import { withPluginApi } from "discourse/lib/plugin-api";

export default apiInitializer(() => {
  withPluginApi("1.34.0", (api) => {
    // Conserve uniquement l'affichage du panneau d'en-tête (si supporté)
    api.addHeaderPanel?.("game-sheet");
  });
});
