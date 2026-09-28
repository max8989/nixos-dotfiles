pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "bar"
import "panels"
import "lock"

ShellRoot {
    id: root
    readonly property var lockController: locker.item
    // A store generation is replaced as a whole; the user service restarts it.
    Component.onCompleted: {
        Quickshell.watchFiles = Config.development;
        // Instantiate this service before its first shortcut so saved settings
        // are restored at login, including when preferences have already loaded.
        Display.restoreNightlight();
        if (!Config.valid)
            console.error(
                        "Invalid shell configuration; run quickshell-dev from the repository or use the generated bundle");
    }
    Variants {
        model: Config.valid && Config.features.bar ? Quickshell.screens : []
        Bar {}
    }
    Menus {
        onPowerRequested: function (action) {
            if (Config.preview)
                return;
            if (["lock", "suspend", "hibernate"].indexOf(action) >= 0) {
                if (root.lockController)
                    root.lockController.request(action === "lock" ? "" : action);
            } else if (action === "logout")
                Runtime.logout();
            else if (action === "reboot" || action === "shutdown")
                Runtime.run([Config.bin.systemctl, action === "shutdown" ? "poweroff" : "reboot"], null);
        }
    }
    Overlays {}
    LazyLoader {
        id: locker
        active: Config.valid && Config.features.lock && !Config.preview
        LockScreen {}
    }
    LazyLoader {
        active: Config.valid && Config.features.polkit && !Config.preview
        PolkitPrompt {}
    }
    IpcHandler {
        target: "menus"
        function toggle(name: string): void {
        Runtime.toggleMenu(name, null);
    }
        function close(): void {
                              Runtime.closeMenu();
                          }
        function current(): string {
            return Runtime.menu;
        }
    }
    IpcHandler {
        target: "audio"
        function volume(delta: int): void {
        Audio.change(false, delta);
    }
        function microphone(delta: int): void {
        Audio.change(true, delta);
    }
        function mute(): void {
                             Audio.mute(false);
                         }
        function muteMicrophone(): void {
        Audio.mute(true);
    }
    }
        IpcHandler {
            target: "display"
            function brightness(delta: int): void {
            Display.brightness(delta);
        }
            function nightlight(): void {
                                       Display.toggleNightlight();
                                   }
            function temperature(delta: int): void {
            Display.adjustNightlight(delta);
        }
        }
            IpcHandler {
                target: "media"
                function control(action: string): void {
                Media.control(action);
            }
            }
                IpcHandler {
                    target: "bar"
                    function toggle(): void {
                    Preferences.barHidden = !Preferences.barHidden;
                }
                    function toggleNightlight(): void {
                                                     Display.toggleNightlight();
                                                 }
                }
            }
