defmodule EventDefinitionWeb.GlobalEventsLive do
  use EventDefinitionWeb, :live_view

  alias EventDefinition.Repo
  import Ecto.Query, only: [from: 2]

  @preset_events %{
    "DEP" => %{
      name: "Départ",
      monitor_type: "MovementMonitor",
      level: 1,
      description: "Détecte le début d'un mouvement",
      category: "physical",
      class: "movement",
      level_group: "movement"
    },
    "MOV" => %{
      name: "Déplacement",
      monitor_type: "MovementMonitor",
      level: 1,
      description: "État de déplacement continu",
      category: "derived",
      class: "movement",
      level_group: "movement"
    },
    "PRK_MOV" => %{
      name: "Déplacement parking",
      monitor_type: "MovementMonitor",
      level: 1,
      description: "Mouvement spécifique au parking",
      category: "derived",
      class: "movement",
      level_group: "movement"
    },
    "ARR" => %{
      name: "Arrivée",
      monitor_type: "MovementMonitor",
      level: 1,
      description: "Détecte la fin d'un mouvement",
      category: "physical",
      class: "movement",
      level_group: "movement"
    },
    "PRK" => %{
      name: "Arrêt",
      monitor_type: "MovementMonitor",
      level: 1,
      description: "Détecte l'arrêt/stationnement",
      category: "physical",
      class: "movement",
      level_group: "movement"
    },
    "LOW_BATTERY" => %{
      name: "Batterie faible",
      monitor_type: "PowerMonitor",
      level: 1,
      description: "Détecte un niveau de batterie bas",
      category: "system",
      class: "power",
      level_group: "power"
    },
    "GPS_LOST" => %{
      name: "Perte signal GPS",
      monitor_type: "ConnectivityMonitor",
      level: 1,
      description: "Perte de signal GPS",
      category: "system",
      class: "connectivity",
      level_group: "connectivity"
    },
    "GPS_RESTORED" => %{
      name: "Signal GPS retrouvé",
      monitor_type: "ConnectivityMonitor",
      level: 1,
      description: "Rétablissement du signal GPS",
      category: "system",
      class: "connectivity",
      level_group: "connectivity"
    },
    "CONN_LOST" => %{
      name: "Connexion perdue",
      monitor_type: "ConnectivityMonitor",
      level: 1,
      description: "Perte de connexion réseau",
      category: "system",
      class: "connectivity",
      level_group: "connectivity"
    },
    "OVERSPEED" => %{
      name: "Excès de vitesse",
      monitor_type: "SpeedMonitor",
      level: 2,
      description: "speed_exceeds",
      category: "alarm",
      class: "speed",
      level_group: "speed"
    },
    "IDLE" => %{
      name: "Inactivité prolongée",
      monitor_type: "IdleMonitor",
      level: 2,
      description: "no_movement",
      category: "alarm",
      class: "alarm",
      level_group: "alarm"
    },
    "GEO_ENTER" => %{
      name: "Entrée de zone",
      monitor_type: "GeofenceMonitor",
      level: 2,
      description: "geofence_enter",
      category: "physical",
      class: "geofence",
      level_group: "geofence"
    },
    "GEO_EXIT" => %{
      name: "Sortie de zone",
      monitor_type: "GeofenceMonitor",
      level: 2,
      description: "geofence_exit",
      category: "physical",
      class: "geofence",
      level_group: "geofence"
    },
    "GEO_INSIDE" => %{
      name: "Dans la zone",
      monitor_type: "GeofenceMonitor",
      level: 2,
      description: "geofence_inside",
      category: "derived",
      class: "geofence",
      level_group: "geofence"
    },
    "POI_NEAR" => %{
      name: "Proximité POI",
      monitor_type: "PoiMonitor",
      level: 2,
      description: "poi_near",
      category: "physical",
      class: "geofence",
      level_group: "poi"
    },
    "POI_APPROACHING" => %{
      name: "Approche POI",
      monitor_type: "PoiMonitor",
      level: 2,
      description: "poi_approaching",
      category: "physical",
      class: "geofence",
      level_group: "poi"
    },
    "POI_LEAVING" => %{
      name: "Départ POI",
      monitor_type: "PoiMonitor",
      level: 2,
      description: "poi_leaving",
      category: "physical",
      class: "geofence",
      level_group: "poi"
    },
    "FUEL_DROP" => %{
      name: "Chute de carburant",
      monitor_type: "FuelMonitor",
      level: 2,
      description: "fuel_drop",
      category: "fuel",
      class: "fuel",
      level_group: "fuel"
    },
    "HARSH_BRAKE" => %{
      name: "Freinage brusque",
      monitor_type: "DrivingMonitor",
      level: 2,
      description: "deceleration_exceeds",
      category: "alarm",
      class: "driving",
      level_group: "driving"
    },
    "IMPACT" => %{
      name: "Impact/choc",
      monitor_type: "AccelerometerMonitor",
      level: 2,
      description: "acceleration_shock",
      category: "alarm",
      class: "accelerometer",
      level_group: "driving"
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(preset_events: @preset_events)
     |> assign(
       form: %{
         "code" => "",
         "name" => "",
         "monitor_type" => "",
         "level" => "",
         "description" => "",
         "category" => "",
         "class" => "",
         "level_group" => ""
       }
     )
     |> assign(categories: ["physical", "derived", "system", "alarm", "fuel"])
     |> assign(
       classes: [
         "movement",
         "power",
         "connectivity",
         "speed",
         "alarm",
         "geofence",
         "fuel",
         "driving",
         "accelerometer"
       ]
     )
     |> assign(
       level_groups: [
         "movement",
         "power",
         "connectivity",
         "speed",
         "alarm",
         "geofence",
         "poi",
         "fuel",
         "driving"
       ]
     )
     |> assign(modal: nil, editing_event: nil, events: load_events())}
  end

  # ========================================================================
  # GESTION DES EVENEMENTS DU FORMULAIRE ET DE L'AUTO-REMPLISSAGE
  # ========================================================================

  @impl true
  def handle_event("update-form", %{"_target" => ["code"], "code" => code}, socket) do
    # Déclenché dès qu'un Code Événement est cliqué/sélectionné dans le dropdown
    form_data =
      case Map.get(@preset_events, code) do
        nil ->
          %{
            "code" => code,
            "name" => "",
            "monitor_type" => "",
            "level" => "",
            "description" => "",
            "category" => "",
            "class" => "",
            "level_group" => ""
          }

        preset ->
          %{
            "code" => code,
            "name" => preset.name,
            "monitor_type" => preset.monitor_type,
            "level" => to_string(preset.level),
            "description" => preset.description,
            "category" => preset.category,
            "class" => preset.class,
            "level_group" => preset.level_group
          }
      end

    {:noreply, assign(socket, form: form_data)}
  end

  @impl true
  def handle_event("update-form", params, socket) do
    # Reçoit les modifications si l'utilisateur change manuellement un champ (comme Catégorie, Classe...)
    updated_form = Map.merge(socket.assigns.form, params)
    {:noreply, assign(socket, form: updated_form)}
  end

  # ========================================================================
  # OUVERTURE / FERMETURE DU MODAL
  # ========================================================================

  @impl true
  def handle_event("open-new-modal", _, socket) do
    {:noreply,
     assign(socket,
       modal: :new,
       form: %{
         "code" => "",
         "name" => "",
         "monitor_type" => "",
         "level" => "",
         "description" => "",
         "category" => "",
         "class" => "",
         "level_group" => ""
       },
       editing_event: nil
     )}
  end

  @impl true
  def handle_event("open-edit-modal", %{"id" => id}, socket) do
    event = Enum.find(socket.assigns.events, fn e -> to_string(e.id) == id end)

    {:noreply,
     assign(socket,
       modal: :edit,
       editing_event: event,
       form: %{
         "code" => event.code,
         "name" => event.name,
         "category" => event.category,
         "class" => event.class,
         "monitor_type" => event.monitor_type,
         "level" => to_string(event.level),
         "description" => event.definition || "",
         "level_group" => event.level_group || ""
       }
     )}
  end

  @impl true
  def handle_event("close-modal", _, socket) do
    {:noreply, assign(socket, modal: nil, form: %{}, editing_event: nil)}
  end

  # ========================================================================
  # ACTIONS EN BASE DE DONNÉES (SAUVEGARDE ET ACTIONS SÉCURISÉES)
  # ========================================================================

  @impl true
  def handle_event("save-new", _, socket) do
    form = socket.assigns.form
    code = form["code"]

    if code && code != "" do
      preset = @preset_events[code]
      name = form["name"] || (preset && preset.name) || code

      # Extraction sécurisée du niveau en Integer pour Ecto
      level_int =
        case Integer.parse(form["level"] || "") do
          {num, _} -> num
          :error -> (preset && preset.level) || 1
        end

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      Repo.insert_all(
        "event_definitions",
        [
          [
            id: Ecto.UUID.dump!(Ecto.UUID.generate()),
            code: code,
            name: name,
            definition: form["description"] || (preset && preset.description),
            category: form["category"] || (preset && preset.category) || "physical",
            class: form["class"] || (preset && preset.class) || "unknown",
            level: level_int,
            level_group: form["level_group"] || (preset && preset.level_group),
            monitor_type:
              form["monitor_type"] || (preset && preset.monitor_type) || "MovementMonitor",
            active: true,
            inserted_at: now,
            updated_at: now
          ]
        ],
        on_conflict: :nothing,
        conflict_target: :code
      )

      Phoenix.PubSub.broadcast(EventDefinition.PubSub, "global_events", {:event_created, code})

      {:noreply,
       socket
       |> assign(modal: nil, form: %{})
       |> assign(events: load_events())
       |> put_flash(:info, "Événement « #{code} » créé avec succès")}
    else
      {:noreply, put_flash(socket, :error, "Veuillez sélectionner un code événement")}
    end
  end

  @impl true
  def handle_event("save-edit", _, socket) do
    event = socket.assigns.editing_event
    form = socket.assigns.form

    if event do
      binary_id = Ecto.UUID.cast!(event.id)

      from(e in "event_definitions", where: e.id == type(^binary_id, Ecto.UUID))
      |> Repo.update_all(
        set: [
          name: form["name"],
          definition: form["description"],
          category: form["category"],
          class: form["class"],
          level_group: form["level_group"]
        ]
      )

      Phoenix.PubSub.broadcast(
        EventDefinition.PubSub,
        "global_events",
        {:event_updated, event.id}
      )

      {:noreply,
       socket
       |> assign(modal: nil, form: %{}, editing_event: nil)
       |> assign(events: load_events())
       |> put_flash(:info, "Événement « #{event.code} » modifié")}
    else
      {:noreply, put_flash(socket, :error, "Événement introuvable")}
    end
  end

  @impl true
  def handle_event("toggle-active", %{"id" => id}, socket) do
    binary_id = Ecto.UUID.cast!(id)
    target = Enum.find(socket.assigns.events, fn e -> to_string(e.id) == id end)

    if target do
      new_status = !target.active

      from(e in "event_definitions", where: e.id == type(^binary_id, Ecto.UUID))
      |> Repo.update_all(set: [active: new_status])

      Phoenix.PubSub.broadcast(
        EventDefinition.PubSub,
        "global_events",
        {:global_event_toggled, id, new_status}
      )

      {:noreply, assign(socket, events: load_events())}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete-event", %{"id" => id}, socket) do
    binary_id = Ecto.UUID.cast!(id)
    target = Enum.find(socket.assigns.events, fn e -> to_string(e.id) == id end)

    if target do
      from(e in "event_definitions", where: e.id == type(^binary_id, Ecto.UUID))
      |> Repo.update_all(set: [active: false])

      Phoenix.PubSub.broadcast(EventDefinition.PubSub, "global_events", {:event_deleted, id})

      {:noreply,
       socket
       |> assign(events: load_events())
       |> put_flash(:info, "Événement « #{target.code} » désactivé")}
    else
      {:noreply, socket}
    end
  end

  # ========================================================================
  # PUBSUB HANDLERS & CHARGEMENT
  # ========================================================================

  @impl true
  def handle_info({:event_created, _id}, socket),
    do: {:noreply, assign(socket, events: load_events())}

  @impl true
  def handle_info({:event_updated, _id}, socket),
    do: {:noreply, assign(socket, events: load_events())}

  @impl true
  def handle_info({:event_deleted, _id}, socket),
    do: {:noreply, assign(socket, events: load_events())}

  @impl true
  def handle_info({:global_event_toggled, _id, _active}, socket),
    do: {:noreply, assign(socket, events: load_events())}

  @impl true
  def handle_info({:global_reset, _active}, socket),
    do: {:noreply, assign(socket, events: load_events())}

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_events do
    from(e in "event_definitions",
      select: %{
        id: e.id,
        code: e.code,
        name: e.name,
        definition: e.definition,
        category: e.category,
        class: e.class,
        level: e.level,
        level_group: e.level_group,
        monitor_type: e.monitor_type,
        active: e.active
      },
      order_by: e.code
    )
    |> Repo.all()
    |> Enum.map(fn event -> %{event | id: normalize_uuid(event.id)} end)
  end

  defp normalize_uuid(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_uuid(id), do: to_string(id)
end
