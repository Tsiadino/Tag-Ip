defmodule EventDefinitionWeb.DownloadController do
  use EventDefinitionWeb, :controller

  def csv(conn, %{"file" => _file}) do
    csv_path = Path.expand("../../../event_descriptions.csv", __DIR__)

    case File.read(csv_path) do
      {:ok, content} ->
        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", ~s[attachment; filename="event_descriptions.csv"])
        |> send_resp(200, content)

      {:error, _} ->
        conn
        |> put_flash(:error, "Fichier event_descriptions.csv introuvable")
        |> redirect(to: "/dashboard")
    end
  end
end
