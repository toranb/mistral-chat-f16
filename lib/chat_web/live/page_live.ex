defmodule ChatWeb.PageLive do
  use ChatWeb, :live_view

  alias Phoenix.LiveView.AsyncResult

  @impl true
  def mount(_, _, socket) do
    user = %{id: 1, name: "toran billups"}
    thread = %{id: 2, title: "apple"}
    messages = []

    socket = socket |> assign(thread: thread, messages: messages, user: user, result: nil, text: nil, loading: false, selected: nil, transformer: nil, mistral: nil, segments: [], output: AsyncResult.ok(AsyncResult.loading(), [])) |> stream(:output, [])

    {:ok, socket}
  end

  @impl true
  def handle_event("change_text", %{"message" => text}, socket) do
    socket = socket |> assign(text: text)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_message", %{"message" => text}, socket) do
    parent = self()

    user_id = socket.assigns.user.id
    thread = socket.assigns.thread
    messages = [%{text: text, thread_id: thread.id, user_id: user_id, inserted_at: DateTime.utc_now()}]

    {:noreply,
     socket
     |> assign(messages: messages, segments: [], text: nil, loading: true, output: AsyncResult.loading())
     |> stream(:output, [], reset: true)
     |> cancel_async(:output)
     |> start_async(:output, fn ->
       for {segment, index} <- Stream.with_index(Nx.Serving.batched_run(ChatServing, text)) do
         send(parent, {:output, {segment, index}})
       end
     end)}
  end

  def handle_info({:output, {segment, index}}, socket) do
    segments = socket.assigns.segments
    new_segments = segments ++ [segment]

    socket = stream(socket, :output, [%{id: "s-#{index}", content: segment}])
    socket = assign(socket, segments: new_segments)
    socket = assign(socket, loading: false)

    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:output, {:ok, _}, socket) do
    socket = assign(socket, :output, AsyncResult.ok(socket.assigns.output, []))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col grow px-2 sm:px-4 lg:px-8 py-10">
      <div class="flex flex-col grow relative -mb-8 mt-2 mt-2">
        <div class="absolute inset-0 gap-4">
          <div class="h-full flex flex-col bg-white shadow-sm border rounded-md">
            <div class="grid-cols-4 h-full grid divide-x">
              <div class="block relative col-span-4">
                <div class="flex absolute inset-0 flex-col">
                  <div class="relative flex grow overflow-y-hidden">
                    <div class="pt-4 pb-1 px-4 flex flex-col grow overflow-y-auto">
                      <%= for message <- @messages do %>
                      <div :if={message.user_id != 1} class="my-2 flex flex-row justify-start space-x-1 self-start items-start">
                        <div class="flex flex-col space-y-0.5 self-start items-start">
                          <div class="bg-gray-200 text-gray-900 ml-0 mr-12 py-2 px-3 inline-flex text-sm rounded-lg whitespace-pre-wrap"><%= message.text %></div>
                          <div class="mx-1 text-xs text-gray-500"><%= Calendar.strftime(message.inserted_at, "%B %d, %-I:%M %p") %></div>
                        </div>
                      </div>
                      <div :if={message.user_id == 1} class="my-2 flex flex-row justify-start space-x-1 self-end items-end">
                        <div class="flex flex-col space-y-0.5 self-end items-end">
                          <div class="bg-purple-600 text-gray-50 ml-12 mr-0 py-2 px-3 inline-flex text-sm rounded-lg whitespace-pre-wrap"><%= message.text %></div>
                          <div class="mx-1 text-xs text-gray-500"><%= Calendar.strftime(message.inserted_at, "%B %d, %-I:%M %p") %></div>
                        </div>
                      </div>
                      <% end %>
                      <div :if={@loading} class="typing"><div class="typing__dot"></div><div class="typing__dot"></div><div class="typing__dot"></div></div>
                      <div :if={!Enum.empty?(@segments)} class="my-2 flex flex-row justify-start space-x-1 self-start items-start">
                        <div class="flex flex-col space-y-0.5 self-end items-end">
                          <div id="output" phx-update="stream" class="bg-gray-200 text-gray-900 ml-0 mr-12 py-2 px-3 text-sm rounded-lg">
                            <span :for={{id, segment} <- @streams.output} id={id}><%= segment.content %></span>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  <form class="px-4 py-2 flex flex-row items-end gap-x-2" phx-submit="add_message" phx-change="change_text">
                    <div class="flex flex-col grow rounded-md border border-gray-300">
                      <div class="relative flex grow">
                        <input id="message" name="message" value={@text} class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-sm placeholder:text-gray-400 text-gray-900" placeholder="Aa" type="text" />
                      </div>
                    </div>
                    <div class="ml-1">
                      <button type="submit" class="flex items-center justify-center h-10 w-10 rounded-full bg-gray-200 hover:bg-gray-300 text-gray-500">
                        <svg class="w-5 h-5 transform rotate-90 -mr-px" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
                        </svg>
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
