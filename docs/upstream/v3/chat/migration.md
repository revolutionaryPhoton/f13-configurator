### Migration auf v3.0.0

Diese Version enthält **Breaking Changes**. Ein Upgrade ohne Anpassung der Konfiguration
schlägt fehl und im ungünstigsten Fall startet der Dienst nicht.
Diese Anleitung beschreibt die notwendigen Schritte in der Reihenfolge, in der sie
sinnvollerweise durchgeführt werden.

---

#### Kurzüberblick

| Änderung | Handlung erforderlich |
| --- | --- |
| Open Policy Agent (OPA) für Berechtigungen (#64) | **Ja** — neuer Container, auch ohne Nutzung agentischer Tools |
| `role`-Einträge in `agentic_chat.yml` (#64) | **Ja** — zwingend entfernen, sonst kein Start möglich |
| Systemprompt nicht mehr überschreibbar (#74) | Nur, wenn Clients `system`-Nachrichten senden |
| Begrenzung der Eingabegrößen (#75) | Nur, wenn sehr große Anfragen üblich sind |
| `context_length` statt `max_context_tokens` (#66) | Empfohlen — Verhalten ändert sich |
| Websuche über MCP statt `tools.websearch` (#57) | Optional — alter Weg funktioniert weiter |

---

#### 1. Open Policy Agent einrichten

Die Berechtigungen für agentische Tools werden nicht mehr in `agentic_chat.yml`
konfiguriert, sondern zentral in einer OPA-Policy. Dafür wird ein zusätzlicher Container
benötigt.
Details zur Policy selbst stehen in [opa.md](opa.md).

**Wen betrifft das?**
Wirksam wird OPA ausschließlich bei agentischen Tool-Anfragen.
Dies ist bislang nur die Websuche über die experimentellen agentischen Endpunkte; die MCP-Anbindung richtet sich an den kommenden agentischen Orchestrator.
Wer diese Endpunkte nicht nutzt, bemerkt fachlich keinen Unterschied.

**OPA muss dennoch eingerichtet werden.**
Der Endpunkt wird beim Start eingelesen, nicht erst beim ersten Tool-Aufruf:
Fehlt `service_endpoints.opa` in `general.yml`, bricht der Start mit `KeyError: 'opa'` ab, und zwar unabhängig davon, ob agentische Tools verwendet werden.
Der Container selbst muss beim Start dagegen noch nicht erreichbar sein.
Der Microservice startet auch ohne ihn und beantwortet normale Chat-Anfragen (siehe *Verhalten bei Ausfall* unten).

Der OPA-Dienst muss im Deployment ergänzt werden.
Die `docker-compose.yml` des Repositorys ist dabei nur eine *Struktur*-Vorlage.
Sie ist eine Entwicklungsumgebung, d. h. sie startet u. a. einen Mock-LLM und ist für den Prod-Betrieb nicht geeignet:

```yaml
  opa:
    image: registry.opencode.de/f13/devops-tools/dockerhub-images/opa:1.18.1-debug
    command:
      - "run"
      - "--server"
      - "--addr=:8181"
      - "--watch"
      - "--set=decision_logs.console=true"
      - "/policies"
    volumes:
      - ./opa/policies:/policies:ro
    healthcheck:
      test: ["CMD", "/opa", "eval", "1"]
      interval: 5s
      timeout: 3s
      retries: 5
```

Zwei Punkte, die für den Prod-Betrieb von der Vorlage abweichen sollten:

- **Port 8181 nicht veröffentlichen.**
  Nur der Chat-Dienst muss OPA erreichen.
  Die OPA-API ist ohne `--authentication`/`--authorization` unauthentifiziert und erlaubt auch *schreibende* Zugriffe:
  Wer den Port erreicht, kann die Berechtigungs-Policy ersetzen.
  In der `docker-compose.yml` ist der Port zu Entwicklungszwecken veröffentlicht.
- **Image-Variante prüfen.**
  Der Tag `1.18.1-debug` enthält eine Shell.
  Schlanker sind die Varianten ohne Suffix beziehungsweise `-static`.
  Dieser Container ist mit 25 statt 61 MB kleiner und hat keine Shell;
  beide funktionieren mit dem obigen Healthcheck.
  Sie liegen derzeit allerdings nicht in der F13-Registry, sondern nur auf Docker Hub.

Der Chat-Microservice muss den Endpunkt kennen.
In der `configs/general.yml` ist zu ergänzen:

```yaml
service_endpoints:
  opa: http://opa:8181/
```

OPA muss zusätzlich in die `depends_on`-Bedingung des Chat-Dienstes aufgenommen werden (`condition: service_healthy`).

**Verhalten bei Ausfall:**
Ist OPA nicht erreichbar, werden alle Tool-Anfragen mit `503` abgelehnt (`Berechtigungsprüfung aktuell nicht verfügbar.`).
Der normale Chat ohne Tools funktioniert davon unberührt weiter.
Für agentische Funktionen muss OPA als relevante Komponente mit eingeplant werden.

##### `role`-Einträge zwingend entfernen

> **Achtung:**
> Verbliebene `role:`-Schlüssel in `configs/agentic_chat.yml` führen dazu, dass der Dienst **nicht startet**.

`WebsearchConfig` ist mit `extra="forbid"` definiert und kennt das Feld `role` nicht mehr.
Ein übrig gebliebener Eintrag ist damit kein ignoriertes Relikt, sondern ein Validierungsfehler beim Start.
Vorher:

```yaml
tools:
  websearch:
    engine: linkup
    secret_path: /chat/secrets/websearch_api.secret
    role: null            # <-- entfernen
```

Nachher:

```yaml
tools:
  websearch:
    engine: linkup
    secret_path: /chat/secrets/websearch_api.secret
```

Die zuvor über `role` abgebildeten Berechtigungen werden in`opa/policies/permissions.rego` über `required_roles` definiert.

---

#### 2. Systemprompt ist nicht mehr durch Clients überschreibbar

Die Rolle `system` wird in `ChatMessage` und `AgenticChatMessage` der API nicht mehr als gültiger Wert akzeptiert.
Zusätzlich werden `system`-Nachrichten vor der Verarbeitung aus der Historie entfernt.

Anfragen mit `"role": "system"`, sowohl in `new_message` oder auch in `chat_history` werden mit `422` und folgender Meldung abgelehnt:

```markdown
Input should be 'user' or 'assistant'
```

Betroffen sind Anwendungen, in denen ein Client bisher eigene Systemanweisungen mitgeschickt hat.
Solche Anfragen schlagen ab v3.0.0 fehl und müssen angepasst werden:
Der Systemprompt wird ausschließlich serverseitig über die Prompt Map des Modells gesetzt.

Das ist beabsichtigt und schließt eine Lücke. Bisher konnte jede aufrufende Stelle den
konfigurierten Systemprompt vollständig ersetzen und damit sämtliche serverseitigen
Vorgaben umgehen.

---

#### 3. Begrenzung der Eingabegrößen

Anfragen werden nun serverseitig in der Größe begrenzt.
Überschreitungen führen zu `422` statt wie bisher stillschweigend verworfen zu werden.

| Feld | Grenze |
| --- | --- |
| `new_message.content` | `max_message_content_length`, sonst abgeleitet (s. u.) |
| `chat_history` | `max_chat_history_length`, Standard **100** Nachrichten |
| `tools` (agentisch) | Anzahl verfügbarer Tools + 5 |
| `tools[].payload` | 50 Schlüssel |

Ist `max_message_content_length` in `configs/general.yml` nicht gesetzt, wird die Grenze aus dem großzügigsten konfigurierten Chat-Modell abgeleitet:
aus dessen Eingabebudget, umgerechnet in Zeichen.
Für ein Modell mit `context_length: 131072` und `max_new_tokens: 2048` ergibt das

```markdown
(131072 - 2048) * 4 = 516096 Zeichen
```

Der Wert ist eine Obergrenze und keine Zusage: Eine Nachricht dieser Länge konkurriert weiter
mit dem Systemprompt und der Historie um dasselbe Budget und wird in der Regel gekürzt.

`max_message_content_length` sollte explizit gesetzt werden, wenn eine feste, vom Modell
unabhängige Grenze benötigt wird, etwa weil ein Modell mit sehr großem Kontextfenster
konfiguriert ist und Anfragen dieser Größe gar nicht erst angenommen werden sollten.

---

#### 4. `context_length` statt `max_context_tokens`

`max_context_tokens` in `configs/llm_models.yml` ist veraltet und wird durch `context_length` ersetzt.
Beim Start erscheint sonst eine Deprecation-Warnung.

> **Hinweis:** Dies ist **keine reine Umbenennung.**
> Die Bedeutung ändert sich.

| | Bedeutung |
| --- | --- |
| `max_context_tokens` (alt) | reines **Eingabe**budget; `max_new_tokens` kam obendrauf |
| `context_length` (neu) | **gesamtes** Kontextfenster, Eingabe *und* Ausgabe |

Beim Kürzen der Historie wird `max_new_tokens` nun vom verfügbaren Eingabebudget abgezogen.
Hier ist der Wert des tatsächlichen Kontextfensters des Modells zu übernehmen:

```yaml
# vorher
max_context_tokens: 131072      # Eingabe; effektiv 131072 + 2048 = 133120 gesamt
# nachher
context_length: 131072          # gesamt, Eingabebudget = 131072 - max_new_tokens
```

Wird der Wert unverändert übernommen, verkleinert sich das Eingabebudget um `max_new_tokens`.
In der Regel ist genau das gewünscht, denn die alte Rechnung konnte das reale Kontextfenster des Modells überschreiten.

---

#### 5. Websuche über MCP

Die Konfiguration von Websuche-Tools erfolgt künftig über den MCP-Standard unter `tools.mcp_endpoints`.
Die bisherige Konfiguration unter `tools.websearch` ist **veraltet, funktioniert aber weiterhin** und erzeugt nur eine Deprecation-Warnung.
Ein Umstieg ist mit diesem Release noch nicht zwingend.

```yaml
tools:
  mcp_endpoints:
    - namespace: websearch
      server_url: https://beispiel.example/mcp
      transport: streamable_http
      auth:
        mode: none          # none | static_header | context_jwt
      include: [web_search]
```

In der API wird ein Tool über seinen Namen angesprochen: `websearch` bei der bisherigen
Konfiguration, bei MCP der vom Server gemeldete Name, im oberen Beispiel `web_search`.

Vor dem Umstieg sind einige Punkte unbedingt zu beachten:

- **Quellen werden derzeit nicht angezeigt.**
  Über den bisherigen Weg erhält die nutzende Person Suchanfrage und Quellenliste als `reason`-Ereignisse.
  Über MCP entfallen diese und die Antwort erscheint ohne Belege.
  Für Anwendungsfälle, in denen Nachvollziehbarkeit gefordert ist, sollte der Umstieg zurückgestellt werden.
- **Tool-Namen sind noch nicht mit dem Namespace qualifiziert.**
  Gleichnamige Tools verschiedener MCP-Server oder ein MCP-Tool mit dem Namen eines bestehenden Tools sind für den Agenten nicht unterscheidbar.
- **Datenschutz.**
  Ein externer MCP-Server erhält jede Suchanfrage.
  Für den Einsatz in der öffentlichen Verwaltung ist ein selbst betriebener Server oder eine vertragliche Grundlage unbedingt zu empfehlen.
  Die in `configs/agentic_chat.yml` hinterlegte URL ist ein Beispiel und keine Empfehlung.

---

#### 6. Ausblick: Gehärtete Prompt Maps

> Diese Prompt Maps sind **nicht Teil von v3.0.0.**
> Sie sind hier aufgeführt, damit Betreiber den Aufwand einplanen können und diese vertesten können.

Auf Grundlage von BSI-Berichten zur Absicherung gegen Prompt Injection wurden gehärtete Varianten der bestehenden Prompt Maps erarbeitet.
Sie umfassen unter anderem eine unveränderliche Identität, eine explizite Instruktions-Hierarchie,
die Behandlung von Dokumenten- und Suchinhalten als reine Daten, harte Verbote zur Preisgabe der Systemanweisung sowie eine Fail-Safe-Regel.

**Erst v3.0.0 macht diese Prompts durchsetzbar.**
Bis einschließlich v2.0.1 konnte jede aufrufende Stelle eine eigene `system`-Nachricht mitschicken und den konfigurierten Systemprompt vollständig ersetzen.
Eine noch so sorgfältige Härtung ließ sich damit in einer einzigen Anfrage aushebeln.
Mit #74 ist dieser Weg geschlossen.

Für den Chat liegt die Map `administration_expert_gehaertet` vor.
Sie soll zukünftig `administration_expert` ersetzen und deckt beide Prompt-Typen ab:
`generate` für den normalen Chat und `generate_tools` für den agentischen Pfad.
Die Tool-Variante enthält zusätzlich Regeln zur Tool-Nutzung sowie den Hinweis, dass Suchergebnisse aus dem offenen Internet besonders manipulationsanfällig sind.

Die Map liegt einsatzbereit in [prompt_maps_gehaertet.yml](prompt_maps_gehaertet.yml), zusammen mit einer Anleitung zur Aktivierung.
Zu beachten: Diese Prompt Map wurde noch nicht produktiv eingesetzt und es ist empfohlen, die Map zunächst in einer Testumgebung zu prüfen und Auswirkungen auf die Qualität der Chatantworten zu bewerten.
Rückmeldungen sind willkommen!

Eine Eigenheit ist beim Einsatz zu beachten:

**Chat-Prompts werden mit Python `str.format()` gerendert.**
Jede geschweifte Klammer ist ein Format-Feld; zulässig ist ausschließlich `{current_date}`.
Eine einzige zusätzliche Klammer führt bei **jeder** Anfrage dieses Modells zu `HTTP 500` - der Fehler tritt erst zur Laufzeit auf, weder Start noch Konfigurationsprüfung schlagen an.

---

#### Prüfung nach dem Upgrade

Empfohlene Kontrollen, um die Migration zu bestätigen:

1. Chat- und OPA-Container sind `healthy`; im Log erscheint keine Deprecation-Warnung zu
   `max_context_tokens`.
2. `GET /llms` liefert die erwarteten Modelle.
3. Eine normale Chat-Anfrage wird beantwortet.
4. Eine Anfrage mit `"role": "system"` wird mit `422` abgelehnt — sowohl in `new_message`
   als auch in `chat_history`.
5. Eine überlange `content`-Eingabe wird mit `422` abgelehnt.
6. Bei gestopptem OPA: Tool-Anfragen liefern `503`, der normale Chat weiterhin `200`.
7. Die Websuche liefert eine Antwort; bei Nutzung von `tools.websearch` zusätzlich die
   Quellenliste.
