const soundPath =
  "/Users/ddd/.config/opencode/vittemacop-alert-notification-pop-cartoon-bubble-pop-pop-up-478078.mp3"
const inputEvents = new Set(["question.asked"])

export const InputNotificationPlugin = async ({ $ }) => ({
  event: async ({ event }) => {
    if (process.platform !== "darwin" || !inputEvents.has(event.type)) return

    try {
      void $`/usr/bin/afplay ${soundPath}`
        .quiet()
        .nothrow()
        .then(
          () => {},
          () => {},
        )
    } catch {
      // Notification failures must not interrupt the pending input prompt.
    }
  },
})
