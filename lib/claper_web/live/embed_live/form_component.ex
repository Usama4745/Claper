defmodule ClaperWeb.EmbedLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Embed

  @impl true
  def update(%{embed: embed} = assigns, socket) do
    changeset = Embed.change_embed(embed)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:dark, fn -> false end)
     |> assign(:embed, list_embed(assigns))
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    embed = Embed.get_embed!(id)
    {:ok, _} = Embed.delete_embed(socket.assigns.event_uuid, embed)

    {:noreply, socket |> push_redirect(to: socket.assigns.return_to)}
  end

  @impl true
  def handle_event("validate", %{"embed" => embed_params}, socket) do
    changeset =
      socket.assigns.embed
      |> Embed.change_embed(embed_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"embed" => embed_params}, socket) do
    save_embed(socket, socket.assigns.live_action, embed_params)
  end

  @impl true
  def handle_event("add_opt", _params, %{assigns: %{changeset: changeset}} = socket) do
    {:noreply, assign(socket, :changeset, changeset |> Embed.add_embed_opt())}
  end

  @impl true
  def handle_event(
        "remove_opt",
        %{"opt" => opt} = _params,
        %{assigns: %{changeset: changeset}} = socket
      ) do
    {opt, _} = Integer.parse(opt)

    embed_opt = Enum.at(Ecto.Changeset.get_field(changeset, :embed_opts), opt)

    {:noreply, assign(socket, :changeset, changeset |> Embed.remove_embed_opt(embed_opt))}
  end

  defp save_embed(socket, :edit, embed_params) do
    case Embed.update_embed(
           socket.assigns.event_uuid,
           socket.assigns.embed,
           embed_params
         ) do
      {:ok, _embed} ->
        {:noreply,
         socket
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_embed(socket, :new, embed_params) do
    case Embed.create_embed(
           embed_params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("position", socket.assigns.position)
           |> Map.put("enabled", false)
         ) do
      {:ok, embed} ->
        {:noreply,
         socket
         |> maybe_change_current_embed(embed)
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp maybe_change_current_embed(socket, %{enabled: true} = embed) do
    embed = Embed.get_embed!(embed.id)

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event_uuid}",
      {:current_embed, embed}
    )

    socket
  end

  defp maybe_change_current_embed(socket, _), do: socket

  defp list_embed(assigns) do
    Embed.list_embed(assigns.presentation_file.id)
  end
end
