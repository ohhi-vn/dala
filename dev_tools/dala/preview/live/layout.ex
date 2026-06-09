defmodule Dala.Designer.Live.Layout do
  @moduledoc """
  Root layout for Dala Designer LiveView.

  Provides the HTML shell with Phoenix LiveView client JS,
  the DesignCanvas drag-and-drop hook, and base styles.
  """

  use Phoenix.Component

  @doc """
  Root layout for the preview designer.
  """
  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Dala Designer</title>
        <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>◆</text></svg>" />
        <script src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
        <.live_head />
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  defp live_head(assigns) do
    ~H"""
    <script>
      // Phoenix LiveView client
      if (typeof window.phx_live_view_loaded === 'undefined') {
        var s = document.createElement('script');
        s.src = 'https://cdn.jsdelivr.net/npm/phoenix@1.7.0/priv/static/phoenix.min.js';
        document.head.appendChild(s);
        var s2 = document.createElement('script');
        s2.src = 'https://cdn.jsdelivr.net/npm/phoenix_live_view@1.0.0/priv/static/phoenix_live_view.min.js';
        s2.onload = function() {
          // Register the DesignCanvas hook
          window.Hooks = window.Hooks || {};
          window.Hooks.DesignCanvas = DesignCanvas;

          // Connect LiveView
          var liveSocket = new LiveView.LiveSocket('/live', Phoenix.Socket, {
            hooks: window.Hooks,
            params: { _csrf_token: '' }
          });
          liveSocket.connect();
          window.liveSocket = liveSocket;
        };
        document.head.appendChild(s2);
      }
    </script>
    <script>
      // DesignCanvas drag-and-drop hook
      var DesignCanvas = {
        mounted() { this.initDragDrop(); },
        updated() { this.initDragDrop(); },
        initDragDrop() {
          var root = this.el;
          root.querySelectorAll('.palette-item[draggable]').forEach(function(el) {
            el.addEventListener('dragstart', function(e) {
              e.dataTransfer.setData('text/plain', el.dataset.dragType);
              e.dataTransfer.effectAllowed = 'copy';
            });
          });
          root.querySelectorAll('.drop-zone').forEach(function(zone) {
            zone.addEventListener('dragover', function(e) {
              e.preventDefault();
              e.dataTransfer.dropEffect = 'copy';
              zone.classList.add('drag-over');
            });
            zone.addEventListener('dragleave', function(e) {
              zone.classList.remove('drag-over');
            });
            zone.addEventListener('drop', function(e) {
              e.preventDefault();
              zone.classList.remove('drag-over');
              var type = e.dataTransfer.getData('text/plain');
              var targetId = zone.dataset.dropTarget;
              if (type && targetId) {
                this.pushEvent('drop_on_node', { type: type, target_id: targetId });
              }
            }.bind(this));
          }.bind(this));
        }
      };
    </script>
    <style>
      *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
      html, body { height: 100%; overflow: hidden; }
    </style>
    """
  end
end
