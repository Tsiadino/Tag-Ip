defmodule EventDefinitionWeb.MonitoringLive do
  use EventDefinitionWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(EventDefinition.PubSub, "monitoring_alerts")

    organizations = EventDefinition.Accounts.Organization |> Ash.read!()

    event_types =
      EventDefinition.Events.EventDefinition
      |> Ash.read!()
      |> Enum.map(& &1.name)
      |> Enum.uniq()
      |> Enum.sort()

    alert_logs =
      EventDefinition.Events.AlertLog
      |> Ash.Query.sort(timestamp: :desc)
      |> Ash.Query.load([:organization])
      |> Ash.read!()

    audit_logs =
      EventDefinition.Events.AuditLog
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(10)
      |> Ash.read!()

    monitoring_config = %{
      polling_interval: 30,
      webhook_url: "https://webhook.site/7e5a7841-0982-411c-83bd-7a7ce6bd7483",
      email_alert: "fannie@event-definition.com",
      logs_enabled: true
    }

    {:ok,
     assign(socket,
       organizations: organizations,
       event_types: event_types,
       selected_org_id: (List.first(organizations) || %{id: nil}).id,
       selected_event: List.first(event_types) || "Aucun événement disponible",
       alert_logs: alert_logs,
       audit_logs: audit_logs,
       monitoring_config: monitoring_config
     )}
  end

  @impl true
  def handle_info({:new_alert, alert}, socket) do
    alert_loaded = Ash.load!(alert, [:organization])

    {:noreply,
     socket
     |> assign(alert_logs: [alert_loaded | socket.assigns.alert_logs])
     |> put_flash(:info, "Nouvelle alerte reçue : #{alert_loaded.event_code}")}
  end

  @impl true
  def handle_event("validate_config", %{"config" => params}, socket) do
    {:noreply,
     assign(socket,
       selected_org_id: params["organization_id"],
       selected_event: params["event_name"]
     )}
  end

  @impl true
  def handle_event("update_config", %{"config" => params}, socket) do
    new_config = %{
      polling_interval: String.to_integer(params["polling_interval"]),
      webhook_url: params["webhook_url"],
      email_alert: params["email_alert"],
      logs_enabled: params["logs_enabled"] == "true"
    }

    audit_params = %{
      organization_id: params["organization_id"],
      action: "Modification Config",
      details: %{polling_interval: params["polling_interval"], webhook_url: params["webhook_url"]},
      user: "Fannie",
      timestamp: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    EventDefinition.Events.AuditLog
    |> Ash.Changeset.for_create(:create, audit_params)
    |> Ash.create!()

    updated_audit_logs =
      EventDefinition.Events.AuditLog
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(10)
      |> Ash.read!()

    {:noreply,
     socket
     |> assign(monitoring_config: new_config, audit_logs: updated_audit_logs)
     |> assign(selected_org_id: params["organization_id"])
     |> assign(selected_event: params["event_name"])
     |> push_event("show_toast", %{
       type: "success",
       message: "✓ Configuration sauvegardée avec succès"
     })
     |> put_flash(:info, "Configuration mise à jour et auditée avec succès")}
  end

  @impl true
  def handle_event("test_webhook", _params, socket) do
    webhook_url = socket.assigns.monitoring_config.webhook_url

    alert_params = %{
      event_code: socket.assigns.selected_event,
      organization_id: socket.assigns.selected_org_id,
      alert_type: "webhook_test",
      severity: "info",
      message: "Test webhook pour #{socket.assigns.selected_event}",
      timestamp: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case EventDefinition.Events.AlertLog
         |> Ash.Changeset.for_create(:create, alert_params)
         |> Ash.create() do
      {:ok, new_alert} ->
        spawn(fn -> Req.post(webhook_url, json: alert_params) end)

        Phoenix.PubSub.broadcast(
          EventDefinition.PubSub,
          "monitoring_alerts",
          {:new_alert, new_alert}
        )

        audit_params = %{
          organization_id: socket.assigns.selected_org_id,
          action: "Test Webhook",
          details: %{event_code: alert_params.event_code, message: alert_params.message},
          user: "Fannie",
          timestamp: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        EventDefinition.Events.AuditLog
        |> Ash.Changeset.for_create(:create, audit_params)
        |> Ash.create()

        updated_audit_logs =
          EventDefinition.Events.AuditLog |> Ash.Query.sort(inserted_at: :desc) |> Ash.read!()

        {:noreply,
         socket
         |> assign(audit_logs: updated_audit_logs)
         |> push_event("show_toast", %{
           type: "info",
           message: "🚀 Alerte test envoyée pour #{alert_params.event_code} !"
         })
         |> put_flash(:info, "Signal envoyé et audité pour #{alert_params.event_code} !")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erreur d'enregistrement PostgreSQL")}
    end
  end
end
