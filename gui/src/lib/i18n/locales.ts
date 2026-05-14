import deMessages from "./de.json";
import esMessages from "./es.json";
import frMessages from "./fr.json";
import { registerCatalog } from "./index.js";

registerCatalog("de", deMessages as Record<string, string>);
registerCatalog("fr", frMessages as Record<string, string>);
registerCatalog("es", esMessages as Record<string, string>);
