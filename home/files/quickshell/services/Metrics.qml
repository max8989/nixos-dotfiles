pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../Logic.js" as Logic

Singleton {
    id: root
    property real cpu: 0
    property var previousCpu: ({
                                   total: 0,
                                   idle: 0
                               })
    property var ram: ({
                           percent: 0,
                           used: 0,
                           total: 0
                       })
    property string networkRate: ""
    property var previousNetwork: ({})
    property var networkDevices: ({})
    property double previousTime: Date.now()
    property var temperatures: ({})
    readonly property var temperature: Object.keys(temperatures).length ? Math.max(...Object.values(
                                                                                       temperatures)) : null
    FolderListModel {
        id: sensors
        folder: "file:///sys/class/hwmon"
        showFiles: false
        showDotAndDotDot: false
    }
    Instantiator {
        model: sensors
        delegate: Scope {
            id: sensor
            required property string filePath
            property string driver: ""
            readonly property bool cpuSensor: driver === "coretemp" || driver === "k10temp" || driver
                                              === "zenpower"
            FileView {
                path: sensor.filePath + "/name"
                printErrors: false
                onLoaded: sensor.driver = text().trim()
            }
            FileView {
                id: sensorTemperature
                path: sensor.cpuSensor ? sensor.filePath + "/temp1_input" : ""
                printErrors: false
                onLoaded: {
                    var value = Number(text().trim()) / 1000;
                    if (isFinite(value) && value > 0 && value < 150) {
                        var next = Object.assign({}, root.temperatures);
                        next[sensor.filePath] = value;
                        root.temperatures = next;
                    }
                }
            }
            Timer {
                interval: 5000
                running: sensor.cpuSensor
                repeat: true
                onTriggered: sensorTemperature.reload()
            }
        }
    }
    FileView {
        id: cpuFile
        path: "/proc/stat"
        onLoaded: {
            var sample = Logic.cpuSample(text());
            root.cpu = Logic.cpuUsage(root.previousCpu, sample);
            root.previousCpu = sample;
        }
    }
    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        onLoaded: root.ram = Logic.memory(text())
    }
    FileView {
        id: networkFile
        path: "/proc/net/dev"
        onLoaded: {
            var sample = Logic.networkSample(text());
            var now = Date.now();
            root.networkRate = Logic.networkRate(root.previousNetwork, sample, (now - root.previousTime)
                                                 / 1000);
            var devices = {}, seconds = (now - root.previousTime) / 1000;
            Object.keys(sample).forEach(name => {
                var previous = root.previousNetwork[name], current = sample[name];
                devices[name] = {rx: current.rx, tx: current.tx,
                    receiving: previous && seconds > 0 ? Math.max(0, current.rx - previous.rx) / seconds : 0,
                    sending: previous && seconds > 0 ? Math.max(0, current.tx - previous.tx) / seconds : 0};
            });
            root.networkDevices = devices;

            root.previousNetwork = sample;
            root.previousTime = now;
        }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            cpuFile.reload();
            memoryFile.reload();
            networkFile.reload();
        }
    }
}
