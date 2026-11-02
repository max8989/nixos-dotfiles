// Public defaults for the pinned Hollama release. Existing browser data wins.
(() => {
  if (localStorage.getItem("hollama-servers") === null) {
    localStorage.setItem(
      "hollama-servers",
      JSON.stringify([
        {
          id: "homeserver",
          label: "Qwen",
          baseUrl: `${location.origin}/ollama`,
          connectionType: "ollama",
          modelFilter: "qwen3.5-uncensored:",
          isVerified: new Date().toISOString(),
          isEnabled: true,
        },
      ]),
    );
  }

  // Hollama 0.37.0 omits Ollama's top-level think field. Preserve the server's
  // existing --think=false workflow for this connection, including new chats.
  const originalFetch = window.fetch.bind(window);
  window.fetch = (resource, options) => {
    const url = typeof resource === "string" ? new URL(resource, location.href) : null;
    if (
      url?.origin === location.origin &&
      url.pathname === "/ollama/api/chat" &&
      typeof options?.body === "string"
    ) {
      options = {
        ...options,
        body: JSON.stringify({ ...JSON.parse(options.body), think: false }),
      };
    }
    return originalFetch(resource, options);
  };
})();
