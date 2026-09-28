pragma ComponentBehavior: Bound
pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import ".."

Singleton {
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0]
                                  || null
    function control(action) {
        if (!player || Config.preview)
            return;
        if (action === "next" && player.canGoNext)
            player.next();
        else if (action === "previous" && player.canGoPrevious)
            player.previous();
        else if (action === "toggle" && player.canTogglePlaying)
            player.togglePlaying();
    }
}
