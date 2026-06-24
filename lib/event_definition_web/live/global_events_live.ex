defmodule EventDefinitionWeb.GlobalEventsLive do
  use EventDefinitionWeb, :live_view

  alias EventDefinition.Repo
  import Ecto.Query, only: [from: 2]

  # Nombre d'éléments par page
  @per_page 10

  @auto_presets %{
    "Départ" => %{
      "monitor_type" => "MovementMonitor",
      "level" => "1",
      "description" => "Détecte le début d'un mouvement",
      "category" => "physical",
      "class" => "movement",
      "level_group" => "movement"
    },
    "Déplacement" => %{
      "monitor_type" => "MovementMonitor",
      "level" => "1",
      "description" => "État de déplacement continu",
      "category" => "derived",
      "class" => "movement",
      "level_group" => "movement"
    },
    "Déplacement parking" => %{
      "monitor_type" => "MovementMonitor",
      "level" => "1",
      "description" => "Mouvement spécifique au parking",
      "category" => "derived",
      "class" => "movement",
      "level_group" => "movement"
    },
    "Arrivée" => %{
      "monitor_type" => "MovementMonitor",
      "level" => "1",
      "description" => "Détecte la fin d'un mouvement",
      "category" => "physical",
      "class" => "movement",
      "level_group" => "movement"
    },
    "Arrêt" => %{
      "monitor_type" => "MovementMonitor",
      "level" => "1",
      "description" => "Détecte l'arrêt/stationnement",
      "category" => "physical",
      "class" => "movement",
      "level_group" => "movement"
    },
    "Batterie faible" => %{
      "monitor_type" => "PowerMonitor",
      "level" => "1",
      "description" => "Détecte un niveau de batterie bas",
      "category" => "system",
      "class" => "power",
      "level_group" => "power"
    },
    "Perte signal GPS" => %{
      "monitor_type" => "ConnectivityMonitor",
      "level" => "1",
      "description" => "Perte de signal GPS",
      "category" => "system",
      "class" => "connectivity",
      "level_group" => "connectivity"
    },
    "Signal GPS retrouvé" => %{
      "monitor_type" => "ConnectivityMonitor",
      "level" => "1",
      "description" => "Rétablissement du signal GPS",
      "category" => "system",
      "class" => "connectivity",
      "level_group" => "connectivity"
    },
    "Connexion perdue" => %{
      "monitor_type" => "ConnectivityMonitor",
      "level" => "1",
      "description" => "Perte de connexion réseau",
      "category" => "system",
      "class" => "connectivity",
      "level_group" => "connectivity"
    },
    "Excès de vitesse" => %{
      "monitor_type" => "SpeedMonitor",
      "level" => "2",
      "description" => "speed_exceeds",
      "category" => "alarm",
      "class" => "speed",
      "level_group" => "speed"
    },
    "Inactivité prolongée" => %{
      "monitor_type" => "IdleMonitor",
      "level" => "2",
      "description" => "no_movement",
      "category" => "alarm",
      "class" => "alarm",
      "level_group" => "alarm"
    },
    "Entrée de zone" => %{
      "monitor_type" => "GeofenceMonitor",
      "level" => "2",
      "description" => "geofence_enter",
      "category" => "physical",
      "class" => "geofence",
      "level_group" => "geofence"
    },
    "Sortie de zone" => %{
      "monitor_type" => "GeofenceMonitor",
      "level" => "2",
      "description" => "geofence_exit",
      "category" => "physical",
      "class" => "geofence",
      "level_group" => "geofence"
    },
    "Dans la zone" => %{
      "monitor_type" => "GeofenceMonitor",
      "level" => "2",
      "description" => "geofence_inside",
      "category" => "derived",
      "class" => "geofence",
      "level_group" => "geofence"
    },
    "Proximité POI" => %{
      "monitor_type" => "PoiMonitor",
      "level" => "2",
      "description" => "poi_near",
      "category" => "geofence",
      "class" => "geofence",
      "level_group" => "poi"
    },
    "Approche POI" => %{
      "monitor_type" => "PoiMonitor",
      "level" => "2",
      "description" => "poi_approaching",
      "category" => "geofence",
      "class" => "geofence",
      "level_group" => "poi"
    },
    "Départ POI" => %{
      "monitor_type" => "PoiMonitor",
      "level" => "2",
      "description" => "poi_leaving",
      "category" => "geofence",
      "class" => "geofence",
      "level_group" => "poi"
    },
    "Chute de carburant" => %{
      "monitor_type" => "FuelMonitor",
      "level" => "2",
      "description" => "fuel_drop",
      "category" => "fuel",
      "class" => "fuel",
      "level_group" => "fuel"
    },
    "Freinage brusque" => %{
      "monitor_type" => "DrivingMonitor",
      "level" => "2",
      "description" => "deceleration_exceeds",
      "category" => "alarm",
      "class" => "driving",
      "level_group" => "driving"
    },
    "Impact/choc" => %{
      "monitor_type" => "AccelerometerMonitor",
      "level" => "2",
      "description" => "acceleration_shock",
      "category" => "alarm",
      "class" => "accelerometer",
      "level_group" => "driving"
    }
  }

  @preset_events %{}

  @impl true
  def mount(_params, _session, socket) do
    all_events = load_events()

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
     |> assign(search_query: nil, selected_category: nil, selected_class: nil)
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
     |> assign(modal: nil, editing_event: nil)
     |> assign(page: 1)
     |> assign_paginated_events(all_events)}
  end

  # Assignation de la liste filtrée et calcul des pages dynamiques
  defp assign_paginated_events(socket, all_events) do
    # 1. On applique les filtres sur la liste fraîchement chargée
    filtered = filter_all_events(all_events, socket.assigns)

    total_filtered = length(filtered)
    # Calcule précisément le nombre total de pages nécessaires
    total_pages = max(1, ceil(total_filtered / @per_page))

    # Sécurité pour éviter que la page courante sorte des limites après filtrage
    current_page = min(socket.assigns.page, total_pages)
    offset = (current_page - 1) * @per_page

    paginated_list = Enum.slice(filtered, offset, @per_page)

    socket
    # total_events_count doit refléter le nombre d'éléments *filtrés*
    |> assign(total_events_count: total_filtered)
    |> assign(total_pages: total_pages, page: current_page)
    |> assign(events: paginated_list)
  end

  # Filtrage robuste gérant les Atomes et les Strings de manière interchangeable
  defp filter_all_events(events, assigns) do
    events
    # 1. Filtre catégorie
    |> Enum.filter(fn e ->
      case assigns.selected_category do
        nil -> true
        "" -> true
        cat -> to_string(e.category) == to_string(cat)
      end
    end)
    # 2. Filtre classe
    |> Enum.filter(fn e ->
      case assigns.selected_class do
        nil -> true
        "" -> true
        cls -> to_string(e.class) == to_string(cls)
      end
    end)
    # 3. Filtre recherche textuelle
    |> Enum.filter(fn e ->
      if assigns.search_query && assigns.search_query != "" do
        q = String.downcase(assigns.search_query)

        String.contains?(String.downcase(e.code || ""), q) ||
          String.contains?(String.downcase(e.name || ""), q)
      else
        true
      end
    end)
  end

  # ========================================================================
  # GESTION DES EVENEMENTS LIVEVIEW (NAVIGATION ET RECHERCHE UNIQUE)
  # ========================================================================

  @impl true
  def handle_event("search-event", %{"value" => query}, socket) do
    query_val = if(query == "", do: nil, else: query)

    {:noreply,
     socket
     |> assign(search_query: query_val, page: 1)
     |> assign_paginated_events(load_events())}
  end

  @impl true
  def handle_event("go-to-page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)

    {:noreply,
     socket
     |> assign(page: page)
     |> assign_paginated_events(load_events())}
  end

  @impl true
  def handle_event("filter-category", %{"category_filter" => cat}, socket) do
    # Si l'utilisateur choisit l'option vide "Toutes les catégories", cat vaut "" -> on met nil
    cat_val = if(cat == "", do: nil, else: cat)

    {:noreply,
     socket
     # On réinitialise à la page 1
     |> assign(selected_category: cat_val, page: 1)
     |> assign_paginated_events(load_events())}
  end

  @impl true
  def handle_event("filter-class", %{"class_filter" => cls}, socket) do
    # Si l'utilisateur choisit l'option vide "Toutes les classes", cls vaut "" -> on met nil
    cls_val = if(cls == "", do: nil, else: cls)

    {:noreply,
     socket
     # On réinitialise à la page 1
     |> assign(selected_class: cls_val, page: 1)
     |> assign_paginated_events(load_events())}
  end

  @impl true
  def handle_event("update-form", params, socket) do
    name = Map.get(params, "name", "")

    updated_fields =
      case Map.get(@auto_presets, name) do
        %{} = preset ->
          params |> Map.merge(preset) |> Map.update("level", "1", &to_string/1)

        nil ->
          params
      end

    new_form = Map.merge(socket.assigns.form, updated_fields)
    {:noreply, assign(socket, form: new_form)}
  end

  # ========================================================================
  # MODALS & ACTIONS BDD
  # ========================================================================

  @impl true
  def handle_event("open-new-modal", _, socket) do
    {:noreply,
     assign(socket,
       modal: :new,
       editing_event: nil,
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
     )}
  end

  @impl true
  def handle_event("open-edit-modal", %{"id" => id}, socket) do
    event = Enum.find(load_events(), fn e -> to_string(e.id) == id end)

    {:noreply,
     assign(socket,
       modal: :edit,
       editing_event: event,
       form: %{
         "code" => event.code,
         "name" => event.name,
         "category" => to_string(event.category || ""),
         "class" => to_string(event.class || ""),
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

  @impl true
  def handle_event("save-edit", _, socket) do
    event = socket.assigns.editing_event
    form = socket.assigns.form

    if event do
      binary_id = Ecto.UUID.dump!(to_string(event.id))

      level_int =
        case Integer.parse(to_string(form["level"] || "")) do
          {num, _} -> num
          :error -> (is_integer(event.level) && event.level) || 1
        end

      from(e in "event_definitions", where: e.id == ^binary_id)
      |> Repo.update_all(
        set: [
          code: form["code"],
          name: form["name"],
          category: form["category"],
          class: form["class"],
          level: level_int,
          monitor_type: form["monitor_type"],
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
       |> assign_paginated_events(load_events())
       |> put_flash(:info, "Événement mis à jour avec succès")}
    else
      {:noreply, put_flash(socket, :error, "Événement introuvable")}
    end
  end

  @impl true
  def handle_event("save-new", _params, socket) do
    form = socket.assigns.form

    attrs = %{
      code: form["code"],
      name: form["name"],
      monitor_type: form["monitor_type"],
      level: String.to_integer(form["level"] || "1"),
      definition: form["description"],
      category: safe_to_atom(form["category"]),
      class: safe_to_atom(form["class"]),
      level_group: form["level_group"]
    }

    case Ash.create(EventDefinition.Events.EventDefinition, attrs) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Événement créé avec succès.")
         |> assign(modal: nil)
         |> assign_paginated_events(load_events())}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Erreur lors de la création : #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def handle_event("toggle-active", %{"id" => id}, socket) do
    event = Ash.get!(EventDefinition.Events.EventDefinition, id)
    new_status = !event.active

    case Ash.update(event, %{active: new_status}) do
      {:ok, _updated_event} ->
        {:noreply,
         socket |> put_flash(:info, "État modifié.") |> assign_paginated_events(load_events())}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Erreur de mise à jour.")}
    end
  end

  @impl true
  def handle_event("delete-event", %{"id" => id}, socket) do
    event = Ash.get!(EventDefinition.Events.EventDefinition, id)

    case Ash.destroy(event) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Événement supprimé.")
         |> assign_paginated_events(load_events())}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Impossible de supprimer.")}
    end
  end

  # Multi-diffusions PubSub
  @impl true
  def handle_info({:event_created, _id}, socket),
    do: {:noreply, assign_paginated_events(socket, load_events())}

  @impl true
  def handle_info({:event_updated, _id}, socket),
    do: {:noreply, assign_paginated_events(socket, load_events())}

  @impl true
  def handle_info({:event_deleted, _id}, socket),
    do: {:noreply, assign_paginated_events(socket, load_events())}

  @impl true
  def handle_info({:global_event_toggled, _id, _active}, socket),
    do: {:noreply, assign_paginated_events(socket, load_events())}

  @impl true
  def handle_info({:global_reset, _active}, socket),
    do: {:noreply, assign_paginated_events(socket, load_events())}

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load_events do
    EventDefinition.Events.EventDefinition
    |> Ash.read!()
    |> Enum.sort_by(& &1.code)
  end

  defp safe_to_atom(value) when value in ["", nil], do: nil

  defp safe_to_atom(value) when is_binary(value) do
    allowed = [
      "physical",
      "derived",
      "system",
      "alarm",
      "fuel",
      "information",
      "infraction",
      "movement",
      "power",
      "connectivity",
      "speed",
      "geofence",
      "driving",
      "accelerometer",
      "unknown"
    ]

    if value in allowed, do: String.to_atom(value), else: :unknown
  end

  defp safe_to_atom(_), do: nil
end
