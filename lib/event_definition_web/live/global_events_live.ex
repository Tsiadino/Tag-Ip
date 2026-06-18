defmodule EventDefinitionWeb.GlobalEventsLive do
  use EventDefinitionWeb, :live_view

  alias EventDefinition.Repo
  import Ecto.Query, only: [from: 2]

  @auto_presets %{
    "Départ" => %{"monitor_type" => "MovementMonitor", "level" => "1", "description" => "Détecte le début d'un mouvement", "category" => "physical", "class" => "movement", "level_group" => "movement"},
    "Déplacement" => %{"monitor_type" => "MovementMonitor", "level" => "1", "description" => "État de déplacement continu", "category" => "derived", "class" => "movement", "level_group" => "movement"},
    "Déplacement parking" => %{"monitor_type" => "MovementMonitor", "level" => "1", "description" => "Mouvement spécifique au parking", "category" => "derived", "class" => "movement", "level_group" => "movement"},
    "Arrivée" => %{"monitor_type" => "MovementMonitor", "level" => "1", "description" => "Détecte la fin d'un mouvement", "category" => "physical", "class" => "movement", "level_group" => "movement"},
    "Arrêt" => %{"monitor_type" => "MovementMonitor", "level" => "1", "description" => "Détecte l'arrêt/stationnement", "category" => "physical", "class" => "movement", "level_group" => "movement"},
    "Batterie faible" => %{"monitor_type" => "PowerMonitor", "level" => "1", "description" => "Détecte un niveau de batterie bas", "category" => "system", "class" => "power", "level_group" => "power"},
    "Perte signal GPS" => %{"monitor_type" => "ConnectivityMonitor", "level" => "1", "description" => "Perte de signal GPS", "category" => "system", "class" => "connectivity", "level_group" => "connectivity"},
    "Signal GPS retrouvé" => %{"monitor_type" => "ConnectivityMonitor", "level" => "1", "description" => "Rétablissement du signal GPS", "category" => "system", "class" => "connectivity", "level_group" => "connectivity"},
    "Connexion perdue" => %{"monitor_type" => "ConnectivityMonitor", "level" => "1", "description" => "Perte de connexion réseau", "category" => "system", "class" => "connectivity", "level_group" => "connectivity"},
    "Excès de vitesse" => %{"monitor_type" => "SpeedMonitor", "level" => "2", "description" => "speed_exceeds", "category" => "alarm", "class" => "speed", "level_group" => "speed"},
    "Inactivité prolongée" => %{"monitor_type" => "IdleMonitor", "level" => "2", "description" => "no_movement", "category" => "alarm", "class" => "alarm", "level_group" => "alarm"},
    "Entrée de zone" => %{"monitor_type" => "GeofenceMonitor", "level" => "2", "description" => "geofence_enter", "category" => "physical", "class" => "geofence", "level_group" => "geofence"},
    "Sortie de zone" => %{"monitor_type" => "GeofenceMonitor", "level" => "2", "description" => "geofence_exit", "category" => "physical", "class" => "geofence", "level_group" => "geofence"},
    "Dans la zone" => %{"monitor_type" => "GeofenceMonitor", "level" => "2", "description" => "geofence_inside", "category" => "derived", "class" => "geofence", "level_group" => "geofence"},
    "Proximité POI" => %{"monitor_type" => "PoiMonitor", "level" => "2", "description" => "poi_near", "category" => "geofence", "class" => "geofence", "level_group" => "poi"},
    "Approche POI" => %{"monitor_type" => "PoiMonitor", "level" => "2", "description" => "poi_approaching", "category" => "geofence", "class" => "geofence", "level_group" => "poi"},
    "Départ POI" => %{"monitor_type" => "PoiMonitor", "level" => "2", "description" => "poi_leaving", "category" => "geofence", "class" => "geofence", "level_group" => "poi"},
    "Chute de carburant" => %{"monitor_type" => "FuelMonitor", "level" => "2", "description" => "fuel_drop", "category" => "fuel", "class" => "fuel", "level_group" => "fuel"},
    "Freinage brusque" => %{"monitor_type" => "DrivingMonitor", "level" => "2", "description" => "deceleration_exceeds", "category" => "alarm", "class" => "driving", "level_group" => "driving"},
    "Impact/choc" => %{"monitor_type" => "AccelerometerMonitor", "level" => "2", "description" => "acceleration_shock", "category" => "alarm", "class" => "accelerometer", "level_group" => "driving"}
  }

  @preset_events %{}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(preset_events: @preset_events)
     |> assign(auto_presets: @auto_presets)
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
     |> assign(classes: ["movement", "power", "connectivity", "speed", "alarm", "geofence", "fuel", "driving", "accelerometer"])
     |> assign(level_groups: ["movement", "power", "connectivity", "speed", "alarm", "geofence", "poi", "fuel", "driving"])
     |> assign(modal: nil, editing_event: nil, events: load_events())}
  end

  # ========================================================================
  # GESTION DES EVENEMENTS DU FORMULAIRE ET DE L'AUTO-REMPLISSAGE
  # ========================================================================

  @impl true
  def handle_event("update-form", params, socket) do
    # On récupère le nom tapé ou sélectionné
    name = Map.get(params, "name", "")

    # Si le nom correspond à un preset, on fusionne ses données automatiques
    updated_fields =
      case Map.get(@auto_presets, name) do
        %{} = preset ->
          params 
          |> Map.merge(preset)
          |> Map.update("level", "1", &to_string/1)
        nil ->
          params
      end

    # Fusion avec l'ancien état pour garder le "code" intact
    new_form = Map.merge(socket.assigns.form, updated_fields)

    {:noreply, assign(socket, form: new_form)}
  end

  # ========================================================================
  # OUVERTURE / FERMETURE DU MODAL
  # ========================================================================

  @impl true
  def handle_event("open-new-modal", _, socket) do
    {:noreply, assign(socket, modal: :new, editing_event: nil, form: %{"code" => "", "name" => "", "monitor_type" => "", "level" => "", "description" => "", "category" => "", "class" => "", "level_group" => ""})}
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
  # ACTIONS EN BASE DE DONNÉES
  # ========================================================================

  @impl true
  def handle_event("save-edit", _, socket) do
    event = socket.assigns.editing_event
    form = socket.assigns.form

    if event do
      # Conversion sécurisée de l'ID en format binaire attendu par Postgres
      binary_id = Ecto.UUID.dump!(to_string(event.id))

      # Sécurisation du parsing du niveau
      level_int =
        case Integer.parse(to_string(form["level"] || "")) do
          {num, _} -> num
          :error -> (is_integer(event.level) && event.level) || 1
        end

      # Mise à jour complète de TOUTES les informations obligatoires
      from(e in "event_definitions", where: e.id == ^binary_id)
      |> Repo.update_all(
        set: [
          code: form["code"],           # OBLIGATOIRE
          name: form["name"],           # OBLIGATOIRE
          category: form["category"],   # OBLIGATOIRE
          class: form["class"],         # OBLIGATOIRE
          level: level_int,             # OBLIGATOIRE
          monitor_type: form["monitor_type"], # OBLIGATOIRE
          definition: form["description"],
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
       |> put_flash(:info, "Événement « #{form["code"]} » mis à jour avec succès")}
    else
      {:noreply, put_flash(socket, :error, "Événement introuvable")}
    end
  end

  # Les autres fonctions (toggle-active, delete-event, etc.) restent identiques...
  @impl true
  def handle_event("save-new", _, socket), do: {:noreply, socket} # Simplifié pour l'exemple
  
  @impl true
  def handle_event("toggle-active", %{"id" => id}, socket) do
    # 1. Récupère l'objet
    event = Ash.get!(EventDefinition.Events.EventDefinition, id)
    
    # 2. Change l'état (l'inverse de l'actuel)
    new_status = !event.active
    
    # 3. Met à jour via Ash
    case Ash.update(event, %{active: new_status}) do
      {:ok, _updated_event} ->
        {:noreply, 
        socket 
        |> put_flash(:info, "État modifié.")
        |> assign(:events, load_events())}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Erreur lors de la mise à jour.")}
    end
  end
  
  @impl true
  def handle_event("delete-event", %{"id" => id}, socket) do
    # 1. Conversion sécurisée de l'ID string/UUID en binaire pour Postgres
    binary_id = Ecto.UUID.dump!(to_string(id))

    # 2. Suppression directe en base de données avec Ecto.Query
    case from(e in "event_definitions", where: e.id == ^binary_id) |> Repo.delete_all() do
      {number_of_deleted_rows, _} when number_of_deleted_rows > 0 ->
        # 3. Notification PubSub si d'autres composants écoutent
        Phoenix.PubSub.broadcast(
          EventDefinition.PubSub,
          "global_events",
          {:event_deleted, id}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Événement supprimé avec succès.")
         |> assign(:events, load_events())} # Recharge proprement la liste rafraîchie

      _ ->
        {:noreply, put_flash(socket, :error, "Impossible de supprimer cet événement ou déjà inexistant.")}
    end
  rescue  
    exception ->
      # Sécurité en cas d'erreur de conversion d'UUID
      {:noreply, put_flash(socket, :error, "Erreur lors de la suppression : #{Exception.message(exception)}")}
  end
  
  @impl true
  def handle_info({:event_created, _id}, socket), do: {:noreply, assign(socket, events: load_events())}
  @impl true
  def handle_info({:event_updated, _id}, socket), do: {:noreply, assign(socket, events: load_events())}
  @impl true
  def handle_info({:event_deleted, _id}, socket), do: {:noreply, assign(socket, events: load_events())}
  @impl true
  def handle_info({:global_event_toggled, _id, _active}, socket), do: {:noreply, assign(socket, events: load_events())}
  @impl true
  def handle_info({:global_reset, _active}, socket), do: {:noreply, assign(socket, events: load_events())}
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_events do
    from(e in "event_definitions",
      select: %{id: e.id, code: e.code, name: e.name, definition: e.definition, category: e.category, class: e.class, level: e.level, level_group: e.level_group, monitor_type: e.monitor_type, active: e.active},
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